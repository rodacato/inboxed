# frozen_string_literal: true

module Inboxed
  module Services
    class CreateHttpEndpoint
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(project_id:, params:)
        record = HttpEndpointRecord.create!(
          project_id: project_id,
          endpoint_type: params[:endpoint_type] || "webhook",
          label: params[:label],
          description: params[:description],
          allowed_methods: params[:allowed_methods] || ["POST"],
          allowed_ips: params[:allowed_ips] || [],
          max_body_bytes: params[:max_body_bytes] || 262_144,
          response_mode: params[:response_mode] || "json",
          response_redirect_url: params[:response_redirect_url],
          response_html: params[:response_html],
          expected_interval_seconds: params[:expected_interval_seconds],
          heartbeat_status: (params[:endpoint_type] == "heartbeat") ? "pending" : nil
        )

        @event_store.publish(
          stream: "HttpEndpoint-#{record.id}",
          events: [
            Events::HttpEndpointCreated.new(
              data: {
                endpoint_id: record.id,
                project_id: project_id,
                endpoint_type: record.endpoint_type,
                token: record.token,
                label: record.label
              }
            )
          ]
        )

        ActionCable.server.broadcast(
          "project_#{project_id}",
          {
            type: "endpoint_created",
            endpoint: {
              id: record.id,
              endpoint_type: record.endpoint_type,
              token: record.token,
              label: record.label,
              request_count: 0
            }
          }
        )

        record
      end
    end
  end
end
