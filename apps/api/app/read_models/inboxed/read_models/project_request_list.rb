# frozen_string_literal: true

module Inboxed
  module ReadModels
    class ProjectRequestList
      def self.call(project_id:, limit:, endpoint_token: nil, method: nil, after: nil)
        scope = HttpRequestRecord
          .joins(:endpoint)
          .includes(:endpoint)
          .where(http_endpoints: {project_id: project_id})

        scope = scope.where(http_endpoints: {token: endpoint_token}) if endpoint_token.present?
        scope = scope.where(method: method.upcase) if method.present?
        scope = apply_cursor(scope, after) if after.present?

        records = scope.order(received_at: :desc, id: :desc).limit(limit + 1).to_a

        total_scope = HttpRequestRecord
          .joins(:endpoint)
          .where(http_endpoints: {project_id: project_id})
        total_scope = total_scope.where(http_endpoints: {token: endpoint_token}) if endpoint_token.present?

        {
          records: records.first(limit),
          has_more: records.size > limit,
          total_count: total_scope.count
        }
      end

      def self.apply_cursor(scope, cursor)
        decoded = JSON.parse(Base64.urlsafe_decode64(cursor)).symbolize_keys
        scope.where(
          "http_requests.received_at < ? OR (http_requests.received_at = ? AND http_requests.id < ?)",
          decoded[:t], decoded[:t], decoded[:id]
        )
      end
    end
  end
end
