# frozen_string_literal: true

require "resolv"

class WebhookEndpointRecord < ApplicationRecord
  self.table_name = "webhook_endpoints"

  belongs_to :project, class_name: "ProjectRecord"
  has_many :deliveries, class_name: "WebhookDeliveryRecord",
    foreign_key: :webhook_endpoint_id, dependent: :destroy

  VALID_EVENT_TYPES = %w[email_received email_deleted inbox_created inbox_purged request_captured heartbeat_down heartbeat_recovered].freeze
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

  PRIVATE_IP_RANGES = [
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("0.0.0.0/8"),
    IPAddr.new("::1/128"),
    IPAddr.new("fc00::/7"),
    IPAddr.new("fe80::/10")
  ].freeze

  def validate_url_protocol
    return if url.blank?

    uri = URI.parse(url)

    unless uri.scheme.in?(%w[http https])
      errors.add(:url, "must use HTTP or HTTPS")
      return
    end

    if uri.scheme == "http" && !%w[localhost 127.0.0.1].include?(uri.host)
      errors.add(:url, "must use HTTPS (HTTP allowed only for localhost)")
      return
    end

    validate_not_private_ip(uri.host)
  rescue URI::InvalidURIError
    errors.add(:url, "is not a valid URL")
  end

  def validate_not_private_ip(host)
    return if host.blank?
    return if %w[localhost].include?(host)

    ip = IPAddr.new(host)
    if PRIVATE_IP_RANGES.any? { |range| range.include?(ip) }
      errors.add(:url, "cannot target private or internal IP addresses")
    end
  rescue IPAddr::InvalidAddressError
    # hostname, not an IP — resolve and check
    begin
      resolved = Resolv.getaddresses(host)
      if resolved.any? { |addr| PRIVATE_IP_RANGES.any? { |range| range.include?(IPAddr.new(addr)) } }
        errors.add(:url, "resolves to a private or internal IP address")
      end
    rescue Resolv::ResolvError
      # can't resolve at validation time, allow it
    end
  end

  def validate_event_types
    return if event_types.blank?
    invalid = event_types - VALID_EVENT_TYPES
    errors.add(:event_types, "contains invalid types: #{invalid.join(", ")}") if invalid.any?
  end
end
