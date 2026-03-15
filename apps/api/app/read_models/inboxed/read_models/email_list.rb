# frozen_string_literal: true

module Inboxed
  module ReadModels
    class EmailList
      def self.for_inbox(inbox_id, limit:, after: nil)
        scope = EmailRecord
          .where(inbox_id: inbox_id)
          .select("emails.*")
          .select("(SELECT COUNT(*) FROM attachments WHERE attachments.email_id = emails.id) AS attachment_count")

        scope = apply_cursor(scope, after) if after
        records = scope.order(received_at: :desc, id: :desc).limit(limit + 1).to_a

        {
          records: records.first(limit),
          has_more: records.size > limit,
          total_count: EmailRecord.where(inbox_id: inbox_id).count
        }
      end

      def self.for_project(project_id, limit:, after: nil, inbox_id: nil)
        scope = EmailRecord
          .joins(:inbox)
          .where(inboxes: {project_id: project_id})
          .select("emails.*")
          .select("inboxes.address AS inbox_address")
          .select("(SELECT COUNT(*) FROM attachments WHERE attachments.email_id = emails.id) AS attachment_count")

        scope = scope.where(inbox_id: inbox_id) if inbox_id.present?
        scope = apply_cursor(scope, after) if after
        records = scope.order(received_at: :desc, id: :desc).limit(limit + 1).to_a

        total_scope = EmailRecord.joins(:inbox).where(inboxes: {project_id: project_id})
        total_scope = total_scope.where(inbox_id: inbox_id) if inbox_id.present?

        {
          records: records.first(limit),
          has_more: records.size > limit,
          total_count: total_scope.count
        }
      end

      def self.apply_cursor(scope, cursor)
        decoded = JSON.parse(Base64.urlsafe_decode64(cursor)).symbolize_keys
        scope.where(
          "received_at < ? OR (received_at = ? AND emails.id < ?)",
          decoded[:t], decoded[:t], decoded[:id]
        )
      end
    end
  end
end
