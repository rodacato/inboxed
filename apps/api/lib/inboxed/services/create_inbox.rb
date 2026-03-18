# frozen_string_literal: true

module Inboxed
  module Services
    class CreateInbox
      def initialize(event_store: EventStore::Store, inbox_repo: Repositories::InboxRepository.new)
        @event_store = event_store
        @inbox_repo = inbox_repo
      end

      def call(project_id:, address:, skip_limits: false)
        normalized = address.strip.downcase

        # Check blocked addresses
        if BlockedAddressRecord.blocked?(normalized)
          raise Inboxed::AddressBlocked.new(normalized)
        end

        existing = InboxRecord.find_by(project_id: project_id, address: normalized)
        return existing if existing

        # Enforce plan limits on new inbox creation
        unless skip_limits
          project = ProjectRecord.find(project_id)
          if project.organization
            org = project.organization
            if org.max_inboxes && org.total_inbox_count >= org.max_inboxes
              raise Inboxed::PlanLimitExceeded.new(
                "Inbox limit of #{org.max_inboxes} reached",
                limit: "max_inboxes",
                current: org.total_inbox_count,
                max: org.max_inboxes
              )
            end
          end
        end

        record = InboxRecord.create!(
          id: SecureRandom.uuid,
          project_id: project_id,
          address: normalized,
          email_count: 0
        )

        @event_store.publish(
          stream: "Inbox-#{record.id}",
          events: [
            Events::InboxCreated.new(
              data: {
                inbox_id: record.id,
                project_id: project_id,
                address: normalized
              }
            )
          ]
        )

        record
      end
    end
  end
end
