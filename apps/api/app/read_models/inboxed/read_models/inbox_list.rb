# frozen_string_literal: true

module Inboxed
  module ReadModels
    class InboxList
      def self.for_project(project_id, limit:, after: nil)
        scope = InboxRecord
          .where(project_id: project_id)

        scope = apply_cursor(scope, after, :created_at) if after
        records = scope.order(created_at: :desc, id: :desc).limit(limit + 1).to_a

        {
          records: records.first(limit),
          has_more: records.size > limit,
          total_count: InboxRecord.where(project_id: project_id).count
        }
      end

      def self.apply_cursor(scope, cursor, sort_field)
        decoded = JSON.parse(Base64.urlsafe_decode64(cursor)).symbolize_keys
        scope.where(
          "#{sort_field} < ? OR (#{sort_field} = ? AND id < ?)",
          decoded[:t], decoded[:t], decoded[:id]
        )
      end
    end
  end
end
