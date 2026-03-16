# frozen_string_literal: true

class HttpRequestSerializer
  def self.render(record)
    {
      id: record.id,
      method: record.method,
      path: record.path,
      content_type: record.content_type,
      ip_address: record.ip_address,
      size_bytes: record.size_bytes,
      received_at: record.received_at.iso8601
    }
  end

  def self.render_detail(record)
    {
      id: record.id,
      method: record.method,
      path: record.path,
      query_string: record.query_string,
      headers: record.headers,
      body: record.body,
      content_type: record.content_type,
      ip_address: record.ip_address,
      size_bytes: record.size_bytes,
      received_at: record.received_at.iso8601
    }
  end
end
