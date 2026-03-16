# frozen_string_literal: true

module Inboxed
  module Services
    class CaptureHttpRequest
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(endpoint:, request_data:)
        record = HttpRequestRecord.create!(
          http_endpoint_id: endpoint.id,
          method: request_data[:method],
          path: request_data[:path],
          query_string: request_data[:query_string],
          headers: request_data[:headers],
          body: request_data[:body],
          content_type: request_data[:content_type],
          ip_address: request_data[:ip_address],
          size_bytes: request_data[:size_bytes],
          received_at: Time.current,
          expires_at: calculate_expiry(endpoint)
        )

        HttpEndpointRecord.where(id: endpoint.id)
          .update_all("request_count = request_count + 1")

        heartbeat_status = update_heartbeat_if_applicable(endpoint)

        publish_event(endpoint, record)
        broadcast_request(endpoint, record)

        {request_id: record.id, heartbeat_status: heartbeat_status}
      end

      private

      def calculate_expiry(endpoint)
        project = ProjectRecord.find(endpoint.project_id)
        Time.current + (project.default_ttl_hours || 168).hours
      end

      def update_heartbeat_if_applicable(endpoint)
        return nil unless endpoint.endpoint_type == "heartbeat"

        now = Time.current
        previous_status = endpoint.heartbeat_status

        updates = {
          last_ping_at: now,
          heartbeat_status: "healthy",
          updated_at: now
        }
        updates[:status_changed_at] = now if previous_status != "healthy"

        HttpEndpointRecord.where(id: endpoint.id).update_all(updates)

        if previous_status != "healthy" && previous_status != "pending"
          publish_heartbeat_recovery(endpoint, previous_status)
        end

        "healthy"
      end

      def publish_event(endpoint, record)
        @event_store.publish(
          stream: "HttpEndpoint-#{endpoint.id}",
          events: [
            Events::HttpRequestCaptured.new(
              data: {
                endpoint_id: endpoint.id,
                endpoint_type: endpoint.endpoint_type,
                request_id: record.id,
                project_id: endpoint.project_id,
                method: record.method,
                path: record.path,
                content_type: record.content_type,
                size_bytes: record.size_bytes
              }
            )
          ]
        )
      end

      def publish_heartbeat_recovery(endpoint, previous_status)
        @event_store.publish(
          stream: "HttpEndpoint-#{endpoint.id}",
          events: [
            Events::HeartbeatStatusChanged.new(
              data: {
                endpoint_id: endpoint.id,
                project_id: endpoint.project_id,
                previous_status: previous_status,
                new_status: "healthy",
                last_ping_at: Time.current.iso8601,
                expected_interval_seconds: endpoint.expected_interval_seconds
              }
            )
          ]
        )
      end

      def broadcast_request(endpoint, record)
        ActionCable.server.broadcast(
          "project_#{endpoint.project_id}",
          {
            type: "request_captured",
            endpoint_id: endpoint.id,
            endpoint_type: endpoint.endpoint_type,
            request: {
              id: record.id,
              method: record.method,
              path: record.path,
              content_type: record.content_type,
              ip_address: record.ip_address,
              size_bytes: record.size_bytes,
              received_at: record.received_at.iso8601
            }
          }
        )
      end
    end
  end
end
