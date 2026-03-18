# frozen_string_literal: true

module Inboxed
  module ReadModels
    class EmailSearch
      def self.search(project_id, query:, limit:, after: nil)
        quoted = ActiveRecord::Base.connection.quote(query)

        scope = EmailRecord
          .joins(inbox: :project)
          .where(inboxes: {project_id: project_id})
          .where(
            "to_tsvector('simple', coalesce(emails.subject, '') || ' ' || coalesce(emails.body_text, '')) @@ plainto_tsquery('simple', ?)",
            query
          )
          .select(
            "emails.*",
            "inboxes.address AS inbox_address",
            Arel.sql("ts_rank(to_tsvector('simple', coalesce(emails.subject, '') || ' ' || coalesce(emails.body_text, '')), plainto_tsquery('simple', #{quoted})) AS relevance")
          )

        scope = apply_cursor(scope, after) if after
        records = scope.order(Arel.sql("relevance DESC"), id: :desc).limit(limit + 1).to_a

        {
          records: records.first(limit),
          has_more: records.size > limit,
          total_count: EmailRecord
            .joins(inbox: :project)
            .where(inboxes: {project_id: project_id})
            .where(
              "to_tsvector('simple', coalesce(emails.subject, '') || ' ' || coalesce(emails.body_text, '')) @@ plainto_tsquery('simple', ?)",
              query
            ).count
        }
      end

      def self.search_all(query:, project_ids:, limit:, after: nil)
        quoted = ActiveRecord::Base.connection.quote(query)

        scope = EmailRecord
          .joins(inbox: :project)
          .where(projects: {id: project_ids})
          .where(
            "to_tsvector('simple', coalesce(emails.subject, '') || ' ' || coalesce(emails.body_text, '')) @@ plainto_tsquery('simple', ?)",
            query
          )
          .select(
            "emails.*",
            "inboxes.address AS inbox_address",
            "projects.name AS project_name",
            Arel.sql("ts_rank(to_tsvector('simple', coalesce(emails.subject, '') || ' ' || coalesce(emails.body_text, '')), plainto_tsquery('simple', #{quoted})) AS relevance")
          )

        scope = apply_cursor(scope, after) if after
        records = scope.order(Arel.sql("relevance DESC"), id: :desc).limit(limit + 1).to_a

        {
          records: records.first(limit),
          has_more: records.size > limit,
          total_count: EmailRecord
            .joins(inbox: :project)
            .where(projects: {id: project_ids})
            .where(
              "to_tsvector('simple', coalesce(emails.subject, '') || ' ' || coalesce(emails.body_text, '')) @@ plainto_tsquery('simple', ?)",
              query
            ).count
        }
      end

      def self.apply_cursor(scope, cursor)
        decoded = JSON.parse(Base64.urlsafe_decode64(cursor)).symbolize_keys
        scope.where("emails.id < ?", decoded[:id])
      end
    end
  end
end
