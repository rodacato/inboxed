# frozen_string_literal: true

module Inboxed
  module ReadModels
    class EndpointList
      def self.for_project(project_id, limit:, endpoint_type: nil, after: nil)
        scope = HttpEndpointRecord.where(project_id: project_id)
        scope = scope.by_type(endpoint_type) if endpoint_type.present?

        scope = apply_cursor(scope, after) if after
        records = scope.order(created_at: :desc, id: :desc).limit(limit + 1).to_a

        {
          records: records.first(limit),
          has_more: records.size > limit,
          total_count: HttpEndpointRecord.where(project_id: project_id)
            .then { |s| endpoint_type.present? ? s.by_type(endpoint_type) : s }
            .count
        }
      end

      def self.apply_cursor(scope, cursor)
        decoded = JSON.parse(Base64.urlsafe_decode64(cursor)).symbolize_keys
        scope.where(
          "created_at < ? OR (created_at = ? AND id < ?)",
          decoded[:t], decoded[:t], decoded[:id]
        )
      end
    end
  end
end
