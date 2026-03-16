# frozen_string_literal: true

class HttpRequestCleanupJob < ApplicationJob
  queue_as :default

  def perform
    deleted = HttpRequestRecord.expired.delete_all
    Rails.logger.info("HttpRequestCleanup: deleted #{deleted} expired requests")
  end
end
