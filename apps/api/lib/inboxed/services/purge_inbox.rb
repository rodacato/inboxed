# frozen_string_literal: true

module Inboxed
  module Services
    class PurgeInbox
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(inbox_id:)
        email_count = EmailRecord.where(inbox_id: inbox_id).count
        AttachmentRecord.joins(:email).where(emails: {inbox_id: inbox_id}).delete_all
        EmailRecord.where(inbox_id: inbox_id).delete_all
        InboxRecord.where(id: inbox_id).update_all(email_count: 0)

        event = Events::InboxPurged.new(data: {inbox_id: inbox_id, deleted_count: email_count})
        @event_store.publish(stream: "Inbox-#{inbox_id}", events: [event])

        email_count
      end
    end
  end
end
