# frozen_string_literal: true

class EmailDetailSerializer
  def self.render(record)
    {
      id: record.id,
      inbox_id: record.inbox_id,
      from: record.from_address,
      to: record.to_addresses,
      cc: record.cc_addresses,
      subject: record.subject,
      body_html: record.body_html,
      body_text: record.body_text,
      raw_headers: record.raw_headers,
      source_type: record.source_type,
      received_at: record.received_at.iso8601,
      expires_at: record.expires_at.iso8601,
      attachments: record.attachments.map { |a| attachment_json(a) }
    }
  end

  def self.attachment_json(att)
    {
      id: att.id,
      filename: att.filename,
      content_type: att.content_type,
      size_bytes: att.size_bytes,
      inline: att.inline,
      download_url: "/api/v1/attachments/#{att.id}/download"
    }
  end
end
