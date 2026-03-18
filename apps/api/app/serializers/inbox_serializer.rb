# frozen_string_literal: true

class InboxSerializer
  def self.render(record)
    {
      id: record.id,
      address: record.address,
      email_count: record.email_count,
      created_at: record.created_at.iso8601
    }
  end
end
