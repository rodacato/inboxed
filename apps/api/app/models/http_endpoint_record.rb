# frozen_string_literal: true

class HttpEndpointRecord < ApplicationRecord
  self.table_name = "http_endpoints"

  belongs_to :project, class_name: "ProjectRecord"
  has_many :requests, class_name: "HttpRequestRecord",
    foreign_key: :http_endpoint_id, dependent: :destroy

  VALID_TYPES = %w[webhook form heartbeat].freeze
  VALID_RESPONSE_MODES = %w[json redirect html].freeze
  VALID_HEARTBEAT_STATUSES = %w[pending healthy late down].freeze
  VALID_HTTP_METHODS = %w[GET POST PUT PATCH DELETE HEAD OPTIONS].freeze

  validates :endpoint_type, inclusion: {in: VALID_TYPES}
  validates :token, presence: true, uniqueness: true
  validates :max_body_bytes, numericality: {greater_than: 0, less_than_or_equal_to: 1_048_576}
  validates :response_mode, inclusion: {in: VALID_RESPONSE_MODES}, allow_nil: true
  validates :heartbeat_status, inclusion: {in: VALID_HEARTBEAT_STATUSES}, allow_nil: true
  validate :validate_allowed_methods

  scope :by_type, ->(type) { where(endpoint_type: type) }
  scope :active_heartbeats, -> {
    where(endpoint_type: "heartbeat")
      .where.not(heartbeat_status: nil)
  }

  before_validation :generate_token, on: :create

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def validate_allowed_methods
    return if allowed_methods.blank?
    invalid = allowed_methods - VALID_HTTP_METHODS
    errors.add(:allowed_methods, "contains invalid methods: #{invalid.join(", ")}") if invalid.any?
  end
end
