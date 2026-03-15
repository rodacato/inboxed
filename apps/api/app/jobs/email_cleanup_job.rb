# frozen_string_literal: true

class EmailCleanupJob < ApplicationJob
  queue_as :maintenance

  def perform
    expired = EmailRecord.expired
    count = expired.count

    AttachmentRecord.where(email_id: expired.select(:id)).delete_all
    expired.delete_all

    InboxRecord.where("email_count > 0").find_each do |inbox|
      actual = EmailRecord.where(inbox_id: inbox.id).count
      inbox.update_column(:email_count, actual) if inbox.email_count != actual
    end

    Rails.logger.info("[EmailCleanup] Deleted #{count} expired emails")
  end
end
