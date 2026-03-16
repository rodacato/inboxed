# frozen_string_literal: true

module Inboxed
  module Services
    class CheckHeartbeats
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call
        endpoints = HttpEndpointRecord.active_heartbeats.to_a
        return if endpoints.empty?

        now = Time.current

        endpoints.each do |endpoint|
          new_status = evaluate_status(endpoint, now)
          next if new_status == endpoint.heartbeat_status

          previous = endpoint.heartbeat_status
          endpoint.update!(
            heartbeat_status: new_status,
            status_changed_at: now
          )

          publish_status_change(endpoint, previous, new_status)
          fire_alert_if_needed(endpoint, previous, new_status)
        end
      end

      private

      def evaluate_status(endpoint, now)
        return "pending" if endpoint.last_ping_at.nil?

        elapsed = now - endpoint.last_ping_at
        interval = endpoint.expected_interval_seconds

        if elapsed <= interval
          "healthy"
        elsif elapsed <= interval * 2
          "late"
        else
          "down"
        end
      end

      def publish_status_change(endpoint, previous, new_status)
        @event_store.publish(
          stream: "HttpEndpoint-#{endpoint.id}",
          events: [
            Events::HeartbeatStatusChanged.new(
              data: {
                endpoint_id: endpoint.id,
                project_id: endpoint.project_id,
                previous_status: previous,
                new_status: new_status,
                last_ping_at: endpoint.last_ping_at&.iso8601,
                expected_interval_seconds: endpoint.expected_interval_seconds
              }
            )
          ]
        )

        ActionCable.server.broadcast(
          "project_#{endpoint.project_id}",
          {
            type: "heartbeat_status_changed",
            endpoint_id: endpoint.id,
            previous_status: previous,
            new_status: new_status
          }
        )
      end

      def fire_alert_if_needed(endpoint, previous, new_status)
        if new_status == "down" && previous != "down"
          dispatch_webhook(endpoint, "heartbeat_down", {
            endpoint_id: endpoint.id,
            label: endpoint.label,
            expected_interval_seconds: endpoint.expected_interval_seconds,
            last_ping_at: endpoint.last_ping_at&.iso8601
          })
        elsif new_status == "healthy" && %w[down late].include?(previous)
          dispatch_webhook(endpoint, "heartbeat_recovered", {
            endpoint_id: endpoint.id,
            label: endpoint.label,
            last_ping_at: endpoint.last_ping_at&.iso8601
          })
        end
      end

      def dispatch_webhook(endpoint, event_type, payload)
        endpoints = WebhookEndpointRecord
          .where(project_id: endpoint.project_id)
          .active_or_failing
          .for_event(event_type)

        delivery_repo = Repositories::WebhookDeliveryRepository.new

        endpoints.each do |webhook|
          delivery = delivery_repo.create(
            webhook_endpoint_id: webhook.id,
            event_type: event_type,
            event_id: SecureRandom.uuid,
            payload: {
              event: event_type,
              event_id: SecureRandom.uuid,
              timestamp: Time.current.iso8601,
              data: payload
            }
          )
          WebhookDeliveryJob.perform_later(delivery.id)
        end
      end
    end
  end
end
