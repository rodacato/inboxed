# frozen_string_literal: true

class WebhookEndpointRecord < ApplicationRecord
  self.table_name = "webhook_endpoints"

  belongs_to :project, class_name: "ProjectRecord"
  has_many :deliveries, class_name: "WebhookDeliveryRecord",
    foreign_key: :webhook_endpoint_id, dependent: :destroy

  VALID_EVENT_TYPES = %w[email_received email_deleted inbox_created inbox_purged].freeze
  VALID_STATUSES = %w[active failing disabled].freeze

  validates :url, presence: true
  validates :event_types, presence: true
  validates :status, inclusion: {in: VALID_STATUSES}
  validates :secret, presence: true
  validate :validate_url_protocol
  validate :validate_event_types

  scope :active, -> { where(status: "active") }
  scope :active_or_failing, -> { where(status: %w[active failing]) }
  scope :for_event, ->(event_type) { where("? = ANY(event_types)", event_type) }

  private

  def validate_url_protocol
    return if url.blank?
    uri = URI.parse(url)
    return if uri.scheme == "https"
    return if uri.scheme == "http" && %w[localhost 127.0.0.1].include?(uri.host)
    errors.add(:url, "must use HTTPS (HTTP allowed only for localhost)")
  rescue URI::InvalidURIError
    errors.add(:url, "is not a valid URL")
  end

  def validate_event_types
    return if event_types.blank?
    invalid = event_types - VALID_EVENT_TYPES
    errors.add(:event_types, "contains invalid types: #{invalid.join(", ")}") if invalid.any?
  end
end
