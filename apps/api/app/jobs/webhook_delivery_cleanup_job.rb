# frozen_string_literal: true

class WebhookDeliveryCleanupJob < ApplicationJob
  queue_as :default

  def perform
    repo = Inboxed::Repositories::WebhookDeliveryRepository.new
    deleted = repo.cleanup_older_than(7.days.ago)
    Rails.logger.info("[Webhooks] Cleaned up #{deleted} delivery records older than 7 days")
  end
end
