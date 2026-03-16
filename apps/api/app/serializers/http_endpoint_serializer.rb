# frozen_string_literal: true

class HttpEndpointSerializer
  def self.render(record)
    base_url = ENV.fetch("INBOXED_BASE_URL", "http://localhost:3000")
    {
      id: record.id,
      endpoint_type: record.endpoint_type,
      token: record.token,
      label: record.label,
      description: record.description,
      url: "#{base_url}/hook/#{record.token}",
      allowed_methods: record.allowed_methods,
      allowed_ips: record.allowed_ips,
      max_body_bytes: record.max_body_bytes,
      request_count: record.request_count,
      response_mode: record.response_mode,
      response_redirect_url: record.response_redirect_url,
      expected_interval_seconds: record.expected_interval_seconds,
      heartbeat_status: record.heartbeat_status,
      last_ping_at: record.last_ping_at&.iso8601,
      status_changed_at: record.status_changed_at&.iso8601,
      created_at: record.created_at.iso8601,
      updated_at: record.updated_at.iso8601
    }
  end
end
