# frozen_string_literal: true

module Admin
  module Endpoints
    class RequestsController < BaseController
      def index
        endpoint = HttpEndpointRecord.find_by!(
          token: params[:endpoint_token],
          project_id: params[:project_id]
        )

        result = Inboxed::ReadModels::HttpRequestList.for_endpoint_record(
          endpoint,
          method: params[:method],
          limit: pagination_limit,
          after: params[:after]
        )

        render json: {
          requests: result[:records].map { |r| HttpRequestSerializer.render(r) },
          pagination: pagination_meta(result)
        }
      end

      def show
        endpoint = HttpEndpointRecord.find_by!(
          token: params[:endpoint_token],
          project_id: params[:project_id]
        )
        request_record = endpoint.requests.find(params[:id])
        render json: {request: HttpRequestSerializer.render_detail(request_record)}
      end

      def destroy
        Inboxed::Services::DeleteHttpRequest.new.call(
          id: params[:id],
          token: params[:endpoint_token],
          project_id: params[:project_id]
        )
        head :no_content
      end
    end
  end
end
