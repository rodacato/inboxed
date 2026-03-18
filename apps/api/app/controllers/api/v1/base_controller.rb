# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include Paginatable
      include ErrorRenderable
      include ApiRenderable

      before_action :authenticate_api_key!
      before_action :set_correlation_id
      after_action :set_rate_limit_headers

      private

      def authenticate_api_key!
        token = extract_bearer_token
        return render_unauthorized("API key required") unless token

        prefix = token[0, 8]
        candidates = ApiKeyRecord.where(token_prefix: prefix).includes(:project)
        api_key = candidates.find { |k| BCrypt::Password.new(k.token_digest) == token }

        unless api_key
          request.env["inboxed.auth_failed"] = true
          return render_unauthorized("Invalid API key")
        end

        @current_api_key = api_key
        @current_project = api_key.project
        request.env["inboxed.api_key_id"] = api_key.id
        api_key.update_column(:last_used_at, Time.current)
      end

      def extract_bearer_token
        request.headers["Authorization"]&.match(/\ABearer\s+(.+)\z/)&.captures&.first
      end

      def set_correlation_id
        @correlation_id = request.headers["X-Correlation-ID"] || SecureRandom.uuid
        response.set_header("X-Correlation-ID", @correlation_id)
      end

      def set_rate_limit_headers
        match_data = request.env["rack.attack.match_data"]
        return unless match_data

        limit = match_data[:limit]
        remaining = limit - match_data[:count]
        period = match_data[:period]

        response.set_header("X-RateLimit-Limit", limit.to_s)
        response.set_header("X-RateLimit-Remaining", [remaining, 0].max.to_s)
        response.set_header("X-RateLimit-Reset", (Time.current.to_i + period).to_s)
      end
    end
  end
end
