# frozen_string_literal: true

class WebhookDeliveryRecord < ApplicationRecord
  self.table_name = "webhook_deliveries"

  belongs_to :webhook_endpoint, class_name: "WebhookEndpointRecord"

  scope :pending, -> { where(status: "pending") }
  scope :retryable, -> { where(status: "pending").where("next_retry_at <= ?", Time.current) }
end
