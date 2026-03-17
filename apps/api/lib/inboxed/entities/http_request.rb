# frozen_string_literal: true

module Inboxed
  module Entities
    class HttpRequest < Dry::Struct
      attribute :id, Types::UUID
      attribute :http_endpoint_id, Types::UUID
      attribute :method, Types::String
      attribute :path, Types::String.optional.default(nil)
      attribute :query_string, Types::String.optional.default(nil)
      attribute :headers, Types::Hash.default({}.freeze)
      attribute :body, Types::String.optional.default(nil)
      attribute :content_type, Types::String.optional.default(nil)
      attribute :ip_address, Types::String.optional.default(nil)
      attribute :size_bytes, Types::Coercible::Integer.default(0)
      attribute :received_at, Types::Time
      attribute :expires_at, Types::Time.optional.default(nil)

      def json_body?
        content_type&.include?("application/json")
      end

      def form_data?
        content_type&.include?("application/x-www-form-urlencoded") ||
          content_type&.include?("multipart/form-data")
      end

      def parsed_json
        return nil unless json_body? && body.present?
        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end

      def parsed_form_fields
        return nil unless form_data? && body.present?
        Rack::Utils.parse_nested_query(body)
      rescue
        nil
      end
    end
  end
end
