# frozen_string_literal: true

module Inboxed
  module Services
    class CreateInbox
      def initialize(event_store: EventStore::Store, inbox_repo: Repositories::InboxRepository.new)
        @event_store = event_store
        @inbox_repo = inbox_repo
      end

      def call(project_id:, address:)
        normalized = address.strip.downcase

        existing = InboxRecord.find_by(project_id: project_id, address: normalized)
        return existing if existing

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
