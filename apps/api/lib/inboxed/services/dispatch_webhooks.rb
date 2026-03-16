# frozen_string_literal: true

module Inboxed
  module Services
    class DispatchWebhooks
      def initialize(
        endpoint_repo: Repositories::WebhookEndpointRepository.new,
        delivery_repo: Repositories::WebhookDeliveryRepository.new
      )
        @endpoint_repo = endpoint_repo
        @delivery_repo = delivery_repo
      end

      def call(event:)
        project_id = resolve_project_id(event)
        return unless project_id

        event_type = event.class.name.demodulize.underscore

        endpoints = @endpoint_repo.active_for(
          project_id: project_id,
          event_type: event_type
        )

        endpoints.each do |endpoint|
          payload = build_payload(event, event_type)

          delivery = @delivery_repo.create(
            webhook_endpoint_id: endpoint.id,
            event_type: event_type,
            event_id: event.event_id,
            payload: payload
          )

          WebhookDeliveryJob.perform_later(delivery.id)
        end
      end

      private

      def resolve_project_id(event)
        case event
        when Events::EmailReceived
          email = EmailRecord.find_by(id: event.data[:email_id])
          email&.inbox&.project_id
        when Events::EmailDeleted, Events::InboxCreated, Events::InboxPurged
          inbox = InboxRecord.find_by(id: event.data[:inbox_id])
          inbox&.project_id
        when Events::HttpRequestCaptured, Events::HttpEndpointCreated,
             Events::HttpEndpointDeleted, Events::HeartbeatStatusChanged
          event.data[:project_id]
        end
      end

      def build_payload(event, event_type)
        {
          event: event_type,
          event_id: event.event_id,
          timestamp: Time.current.iso8601,
          data: event.data
        }
      end
    end
  end
end
