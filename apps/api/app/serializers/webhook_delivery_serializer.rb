# frozen_string_literal: true

class WebhookDeliverySerializer
  def self.render(record)
    {
      id: record.id,
      event_type: record.event_type,
      event_id: record.event_id,
      status: record.status,
      http_status: record.http_status,
      attempt_count: record.attempt_count,
      created_at: record.created_at.iso8601,
      last_attempted_at: record.last_attempted_at&.iso8601
    }
  end
end
