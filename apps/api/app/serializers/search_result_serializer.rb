# frozen_string_literal: true

class SearchResultSerializer
  def self.render(record)
    {
      id: record.id,
      inbox_id: record.inbox_id,
      inbox_address: record.try(:inbox_address),
      from: record.from_address,
      subject: record.subject,
      preview: (record.body_text || "").truncate(200),
      received_at: record.received_at.iso8601,
      relevance: record.try(:relevance)&.to_f
    }
  end
end
