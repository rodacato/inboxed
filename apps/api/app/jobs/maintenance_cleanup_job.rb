# frozen_string_literal: true

class MaintenanceCleanupJob < ApplicationJob
  queue_as :default

  def perform
    sessions_deleted = SessionRecord.where("updated_at < ?", 7.days.ago).delete_all

    invitations_deleted = InvitationRecord.expired.where(accepted_at: nil).delete_all

    users_deleted = 0
    if ENV["OUTBOUND_SMTP_HOST"].present?
      users_deleted = UserRecord.unverified.where("created_at < ?", 48.hours.ago).destroy_all.count
    end

    Rails.logger.info(
      "MaintenanceCleanup: sessions=#{sessions_deleted} " \
      "invitations=#{invitations_deleted} users=#{users_deleted}"
    )
  end
end
