# frozen_string_literal: true

class WebhookEndpointSerializer
  def self.render(record, include_secret: false)
    result = {
      id: record.id,
      url: record.url,
      event_types: record.event_types,
      status: record.status,
      description: record.description,
      failure_count: record.failure_count,
      created_at: record.created_at.iso8601,
      updated_at: record.updated_at.iso8601
    }
    result[:secret] = record.secret if include_secret
    result
  end

  def self.render_with_stats(record, stats)
    render(record).merge(stats: stats)
  end
end
