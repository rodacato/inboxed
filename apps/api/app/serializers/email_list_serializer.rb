# frozen_string_literal: true

class EmailListSerializer
  def self.render(record)
    {
      id: record.id,
      from: record.from_address,
      to: record.to_addresses,
      subject: record.subject,
      preview: (record.body_text || "").truncate(200),
      has_attachments: (record.try(:attachment_count) || 0) > 0,
      attachment_count: record.try(:attachment_count) || 0,
      source_type: record.source_type,
      inbox_address: record.try(:inbox_address),
      received_at: record.received_at.iso8601
    }
  end
end
