# frozen_string_literal: true

class HttpRequestRecord < ApplicationRecord
  self.table_name = "http_requests"

  belongs_to :endpoint, class_name: "HttpEndpointRecord",
    foreign_key: :http_endpoint_id

  scope :expired, -> { where("expires_at < ?", Time.current) }
end
