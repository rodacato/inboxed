# frozen_string_literal: true

module Inboxed
  module Services
    class WaitForRequest
      MAX_TIMEOUT = 30
      POLL_INTERVAL = 0.5

      def call(token:, project_id:, method: nil, timeout_seconds: 30)
        endpoint = HttpEndpointRecord
          .where(project_id: project_id)
          .find_by!(token: token)

        timeout = [timeout_seconds.to_i, MAX_TIMEOUT].min
        cutoff = Time.current
        deadline = Time.current + timeout

        loop do
          request = find_matching_request(endpoint, method, cutoff)
          return request if request
          break if Time.current >= deadline
          sleep POLL_INTERVAL
        end

        nil
      end

      private

      def find_matching_request(endpoint, method, since)
        scope = HttpRequestRecord
          .where(http_endpoint_id: endpoint.id)
          .where("received_at >= ?", since)
          .order(received_at: :desc)

        scope = scope.where(method: method.upcase) if method.present?
        scope.first
      end
    end
  end
end
