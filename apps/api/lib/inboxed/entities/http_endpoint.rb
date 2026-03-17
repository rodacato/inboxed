# frozen_string_literal: true

module Inboxed
  module Entities
    class HttpEndpoint < Dry::Struct
      attribute :id, Types::UUID
      attribute :project_id, Types::UUID
      attribute :endpoint_type, ValueObjects::EndpointType
      attribute :token, Types::String
      attribute :label, Types::String.optional.default(nil)
      attribute :description, Types::String.optional.default(nil)
      attribute :allowed_methods, Types::Array.of(Types::String)
      attribute :max_body_bytes, Types::Coercible::Integer
      attribute :allowed_ips, Types::Array.of(Types::String).default([].freeze)
      attribute :request_count, Types::Coercible::Integer.default(0)
      attribute :created_at, Types::Time

      attribute :form_config, ValueObjects::FormConfig.optional.default(nil)
      attribute :heartbeat_config, ValueObjects::HeartbeatConfig.optional.default(nil)

      def webhook? = endpoint_type == "webhook"
      def form? = endpoint_type == "form"
      def heartbeat? = endpoint_type == "heartbeat"

      def accepts_method?(method)
        allowed_methods.include?(method.to_s.upcase)
      end

      def accepts_ip?(ip)
        return true if allowed_ips.empty?
        allowed_ips.include?(ip)
      end
    end
  end
end
