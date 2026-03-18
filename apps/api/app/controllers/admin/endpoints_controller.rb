# frozen_string_literal: true

module Admin
  class EndpointsController < BaseController
    include TrialEnforced
    include PlanLimitsEnforced
    include VerificationEnforced

    before_action :enforce_email_verified!, only: [:create]
    before_action :enforce_endpoint_limit!, only: [:create]

    def index
      project = current_project

      result = Inboxed::ReadModels::EndpointList.for_project(
        project.id,
        endpoint_type: params[:type],
        limit: pagination_limit,
        after: params[:after]
      )

      render json: {
        endpoints: result[:records].map { |r| HttpEndpointSerializer.render(r) },
        pagination: pagination_meta(result)
      }
    end

    def show
      endpoint = HttpEndpointRecord.find_by!(
        token: params[:token],
        project_id: params[:project_id]
      )
      render json: {endpoint: HttpEndpointSerializer.render(endpoint)}
    end

    def create
      endpoint = Inboxed::Services::CreateHttpEndpoint.new.call(
        project_id: params[:project_id],
        params: endpoint_params
      )
      render json: {endpoint: HttpEndpointSerializer.render(endpoint)}, status: :created
    end

    def update
      endpoint = Inboxed::Services::UpdateHttpEndpoint.new.call(
        token: params[:token],
        project_id: params[:project_id],
        params: endpoint_params
      )
      render json: {endpoint: HttpEndpointSerializer.render(endpoint)}
    end

    def destroy
      Inboxed::Services::DeleteHttpEndpoint.new.call(
        token: params[:token],
        project_id: params[:project_id]
      )
      head :no_content
    end

    def purge
      deleted = Inboxed::Services::PurgeHttpRequests.new.call(
        token: params[:token],
        project_id: params[:project_id]
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
