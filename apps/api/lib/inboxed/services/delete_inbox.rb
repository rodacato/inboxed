# frozen_string_literal: true

module Inboxed
  module Services
    class DeleteInbox
      def call(inbox_id:)
        inbox = InboxRecord.find(inbox_id)
        AttachmentRecord.joins(:email).where(emails: {inbox_id: inbox_id}).delete_all
        EmailRecord.where(inbox_id: inbox_id).delete_all
        inbox.destroy!
      end
    end
  end
end
