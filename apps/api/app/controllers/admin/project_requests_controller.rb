# frozen_string_literal: true

module Admin
  class ProjectRequestsController < BaseController
    def index
      result = Inboxed::ReadModels::ProjectRequestList.call(
        project_id: params[:project_id],
        endpoint_token: params[:endpoint_token],
        method: params[:method],
        limit: pagination_limit,
        after: params[:after]
      )

      render json: {
        requests: result[:records].map { |r|
          HttpRequestSerializer.render(r).merge(
            endpoint: {
              token: r.endpoint.token,
              label: r.endpoint.label,
              endpoint_type: r.endpoint.endpoint_type
            }
          )
        },
        pagination: pagination_meta(result)
      }
    end

    def show
      request_record = HttpRequestRecord
        .joins(:endpoint)
        .where(http_endpoints: {project_id: params[:project_id]})
        .find(params[:id])

      base_url = ENV.fetch("INBOXED_BASE_URL", "http://localhost:3100")
      render json: {
        request: HttpRequestSerializer.render_detail(request_record).merge(
          endpoint: {
            token: request_record.endpoint.token,
            label: request_record.endpoint.label,
            endpoint_type: request_record.endpoint.endpoint_type,
            url: "#{base_url}/hook/#{request_record.endpoint.token}"
          }
        )
      }
    end
  end
end
