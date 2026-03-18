# frozen_string_literal: true

module Admin
  class SearchController < BaseController
    def show
      query = params[:q].to_s.strip
      return render json: {error: "Query parameter 'q' is required"}, status: :bad_request if query.blank?

      result = Inboxed::ReadModels::EmailSearch.search_all(
        query: query,
        project_ids: tenant_project_ids,
        limit: pagination_limit,
        after: params[:after]
      )

      render json: {
        emails: result[:records].map { |r| serialize_search_result(r) },
        pagination: pagination_meta(result)
      }
    end

    private

    def serialize_search_result(record)
      {
        id: record.id,
        inbox_id: record.inbox_id,
        inbox_address: record.try(:inbox_address),
        project_name: record.try(:project_name),
        from: record.from_address,
        subject: record.subject,
        preview: (record.body_text || "").truncate(200),
        received_at: record.received_at.iso8601,
        relevance: record.try(:relevance)&.to_f
      }
    end
  end
end
