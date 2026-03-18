# frozen_string_literal: true

module Inboxed
  module Services
    class ReceiveEmail
      def initialize(
        parser: ParseMime.new,
        inbox_repo: Repositories::InboxRepository.new,
        email_repo: Repositories::EmailRepository.new,
        event_store: EventStore::Store
      )
        @parser = parser
        @inbox_repo = inbox_repo
        @email_repo = email_repo
        @event_store = event_store
      end

      def call(project_id:, raw_source:, envelope_to:, source_type:)
        parsed = @parser.call(raw_source)
        ttl_hours = resolve_ttl(project_id)

        # Enforce daily email limit and check blocked addresses
        project = ProjectRecord.find(project_id)
        if project.organization
          org = project.organization
          if org.max_emails_per_day
            usage = org.today_usage
            if usage.emails_count >= org.max_emails_per_day
              raise Inboxed::PlanLimitExceeded.new(
                "Daily email limit of #{org.max_emails_per_day} reached",
                limit: "max_emails_per_day",
                current: usage.emails_count,
                max: org.max_emails_per_day
              )
            end
          end
        end

        # Check blocked addresses
        envelope_to.each do |recipient|
          if BlockedAddressRecord.blocked?(recipient)
            raise Inboxed::AddressBlocked.new(recipient)
          end
        end

        envelope_to.each do |recipient|
          inbox = @inbox_repo.find_or_create_by_address(
            project_id: project_id,
            address: recipient
          )

          email_id = SecureRandom.uuid
          expires_at = Time.current + ttl_hours.hours

          inbox_aggregate = @event_store.load_aggregate(
            Aggregates::InboxAggregate, inbox.id
          )

          inbox_aggregate.receive_email(
            id: email_id,
            from: parsed.from,
            to: parsed.to,
            subject: parsed.subject,
            source_type: source_type,
            expires_at: expires_at
          )

          @event_store.publish(
            stream: inbox_aggregate.stream_name,
            events: inbox_aggregate.pending_events,
            metadata: {correlation_id: email_id}
          )

          @email_repo.save(
            id: email_id,
            inbox_id: inbox.id,
            parsed: parsed,
            raw_source: raw_source,
            source_type: source_type,
            expires_at: expires_at
          )

          @email_repo.save_attachments(email_id, parsed.attachments) if parsed.attachments.any?
          @inbox_repo.increment_email_count(inbox.id)

          inbox_aggregate.clear_pending_events
        end

        # Track daily usage
        if project.organization_id
          DailyUsageCounterRecord.increment_emails!(project.organization_id)
        end
      end

      private

      def resolve_ttl(project_id)
        project = ProjectRecord.find(project_id)
        project.default_ttl_hours || ENV.fetch("EMAIL_TTL_HOURS", 168).to_i
      end
    end
  end
end
