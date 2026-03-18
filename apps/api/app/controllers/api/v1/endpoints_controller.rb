# frozen_string_literal: true

module Api
  module V1
    class EndpointsController < BaseController
      def index
        result = Inboxed::ReadModels::EndpointList.for_project(
          @current_project.id,
          endpoint_type: params[:type],
          limit: pagination_limit,
          after: params[:after]
        )

        render_collection(:endpoints, result[:records], result, serializer: HttpEndpointSerializer)
      end

      def create
        endpoint = Inboxed::Services::CreateHttpEndpoint.new.call(
          project_id: @current_project.id,
          params: endpoint_params
        )

        render_resource(:endpoint, endpoint, serializer: HttpEndpointSerializer, status: :created)
      end

      def show
        endpoint = HttpEndpointRecord
          .where(project_id: @current_project.id)
          .find_by!(token: params[:token])

        render_resource(:endpoint, endpoint, serializer: HttpEndpointSerializer)
      end

      def update
        endpoint = Inboxed::Services::UpdateHttpEndpoint.new.call(
          token: params[:token],
          project_id: @current_project.id,
          params: endpoint_params
        )

        render_resource(:endpoint, endpoint, serializer: HttpEndpointSerializer)
      end

      def destroy
        Inboxed::Services::DeleteHttpEndpoint.new.call(
          token: params[:token],
          project_id: @current_project.id
        )
        head :no_content
      end

      def purge
        deleted = Inboxed::Services::PurgeHttpRequests.new.call(
          token: params[:token],
          project_id: @current_project.id
        )
        render json: {deleted_count: deleted}
      end

      private

      def endpoint_params
        params.permit(
          :endpoint_type, :label, :description,
          :max_body_bytes, :response_mode, :response_redirect_url,
          :response_html, :expected_interval_seconds,
          allowed_methods: [], allowed_ips: []
        )
      end
    end
  end
end
