# frozen_string_literal: true

module Inboxed
  module Repositories
    class WebhookDeliveryRepository
      def create(webhook_endpoint_id:, event_type:, event_id:, payload:)
        WebhookDeliveryRecord.create!(
          id: SecureRandom.uuid,
          webhook_endpoint_id: webhook_endpoint_id,
          event_type: event_type,
          event_id: event_id,
          payload: payload,
          status: "pending",
          attempt_count: 0
        )
      end

      def find(id)
        WebhookDeliveryRecord.find(id)
      end

      def list_for_endpoint(endpoint_id, limit: 20, after: nil)
        scope = WebhookDeliveryRecord
          .where(webhook_endpoint_id: endpoint_id)
          .order(created_at: :desc)

        if after
          cursor_record = WebhookDeliveryRecord.find_by(id: after)
          scope = scope.where("created_at < ?", cursor_record.created_at) if cursor_record
        end

        records = scope.limit(limit + 1).to_a
        has_more = records.size > limit
        records = records.first(limit)

        {records: records, has_more: has_more, total_count: nil}
      end

      def mark_delivered(record, http_status:, response_body: nil)
        record.update!(
          status: "delivered",
          http_status: http_status,
          response_body: response_body&.truncate(1024),
          attempt_count: record.attempt_count + 1,
          last_attempted_at: Time.current
        )
      end

      def mark_attempt_failed(record, http_status: nil, response_body: nil, next_retry_at: nil)
        record.update!(
          http_status: http_status,
          response_body: response_body&.truncate(1024),
          attempt_count: record.attempt_count + 1,
          last_attempted_at: Time.current,
          next_retry_at: next_retry_at,
          status: next_retry_at ? "pending" : "failed"
        )
      end

      def stats_for_endpoint(endpoint_id)
        counts = WebhookDeliveryRecord
          .where(webhook_endpoint_id: endpoint_id)
          .group(:status)
          .count

        {
          total_deliveries: counts.values.sum,
          successful: counts["delivered"] || 0,
          failed: counts["failed"] || 0,
          pending: counts["pending"] || 0
        }
      end

      def cleanup_older_than(cutoff)
        WebhookDeliveryRecord.where("created_at < ?", cutoff).delete_all
      end
    end
  end
end
