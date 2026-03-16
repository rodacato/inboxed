# frozen_string_literal: true

module Api
  module V1
    module Endpoints
      class RequestsController < BaseController
        def index
          result = Inboxed::ReadModels::HttpRequestList.for_endpoint(
            token: params[:endpoint_token],
            project_id: @current_project.id,
            method: params[:method],
            limit: pagination_limit,
            after: params[:after]
          )

          render json: {
            data: result[:records].map { |r| HttpRequestSerializer.render(r) },
            meta: pagination_meta(result)
          }
        end

        def show
          endpoint = HttpEndpointRecord
            .where(project_id: @current_project.id)
            .find_by!(token: params[:endpoint_token])

          request_record = endpoint.requests.find(params[:id])

          render json: {
            data: HttpRequestSerializer.render_detail(request_record)
          }
        end

        def destroy
          Inboxed::Services::DeleteHttpRequest.new.call(
            id: params[:id],
            token: params[:endpoint_token],
            project_id: @current_project.id
          )
          head :no_content
        end

        def wait
          result = Inboxed::Services::WaitForRequest.new.call(
            token: params[:endpoint_token],
            project_id: @current_project.id,
            method: params[:method],
            timeout_seconds: params.fetch(:timeout, 30)
          )

          if result
            render json: {data: HttpRequestSerializer.render_detail(result)}
          else
            head :request_timeout
          end
        end
      end
    end
  end
end
