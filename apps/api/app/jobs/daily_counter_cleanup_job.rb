# frozen_string_literal: true

class DailyCounterCleanupJob < ApplicationJob
  queue_as :default

  def perform
    # Keep 7 days of usage history, delete older
    deleted = DailyUsageCounterRecord.where("date < ?", 7.days.ago.to_date).delete_all
    Rails.logger.info("[DailyCounterCleanup] Deleted #{deleted} old counter records")
  end
end
