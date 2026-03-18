# frozen_string_literal: true

module Api
  module V1
    class SearchController < BaseController
      def show
        query = params[:q].to_s.strip
        if query.blank?
          return render_problem(
            type: "bad-request",
            title: "Bad request",
            detail: "Query parameter 'q' is required",
            status: :bad_request
          )
        end

        result = Inboxed::ReadModels::EmailSearch.search(
          @current_project.id,
          query: query,
          limit: pagination_limit,
          after: params[:after]
        )

        render_collection(:emails, result[:records], result, serializer: SearchResultSerializer)
      end
    end
  end
end
