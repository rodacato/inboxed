# frozen_string_literal: true

module Inboxed
  module Services
    class DeleteEmail
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(email_id:)
        email = EmailRecord.find(email_id)
        inbox_id = email.inbox_id

        AttachmentRecord.where(email_id: email_id).delete_all
        email.destroy!
        InboxRecord.where(id: inbox_id).update_counters(email_count: -1)

        inbox_aggregate = @event_store.load_aggregate(Aggregates::InboxAggregate, inbox_id)
        inbox_aggregate.delete_email(email_id: email_id)
        @event_store.publish(
          stream: inbox_aggregate.stream_name,
          events: inbox_aggregate.pending_events
        )
        inbox_aggregate.clear_pending_events
      end
    end
  end
end
