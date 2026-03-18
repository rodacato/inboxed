# frozen_string_literal: true

module Api
  module V1
    module Webhooks
      class DeliveriesController < BaseController
        def index
          endpoint = WebhookEndpointRecord.find_by!(
            id: params[:webhook_id],
            project_id: @current_project.id
          )

          repo = Inboxed::Repositories::WebhookDeliveryRepository.new
          result = repo.list_for_endpoint(
            endpoint.id,
            limit: pagination_limit,
            after: params[:after]
          )

          render_collection(:deliveries, result[:records], result, serializer: WebhookDeliverySerializer)
        end
      end
    end
  end
end
