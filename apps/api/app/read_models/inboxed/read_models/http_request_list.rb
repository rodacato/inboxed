# frozen_string_literal: true

module Inboxed
  module ReadModels
    class HttpRequestList
      def self.for_endpoint(token:, project_id:, limit:, method: nil, after: nil)
        endpoint = HttpEndpointRecord
          .where(project_id: project_id)
          .find_by!(token: token)

        for_endpoint_record(endpoint, method: method, limit: limit, after: after)
      end

      def self.for_endpoint_record(endpoint, limit:, method: nil, after: nil)
        scope = HttpRequestRecord.where(http_endpoint_id: endpoint.id)
        scope = scope.where(method: method.upcase) if method.present?

        scope = apply_cursor(scope, after) if after
        records = scope.order(received_at: :desc, id: :desc).limit(limit + 1).to_a

        {
          records: records.first(limit),
          has_more: records.size > limit,
          total_count: HttpRequestRecord.where(http_endpoint_id: endpoint.id).count
        }
      end

      def self.apply_cursor(scope, cursor)
        decoded = JSON.parse(Base64.urlsafe_decode64(cursor)).symbolize_keys
        scope.where(
          "received_at < ? OR (received_at = ? AND id < ?)",
          decoded[:t], decoded[:t], decoded[:id]
        )
      end
    end
  end
end
