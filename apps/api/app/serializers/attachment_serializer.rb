# frozen_string_literal: true

class AttachmentSerializer
  def self.render(record)
    {
      id: record.id,
      filename: record.filename,
      content_type: record.content_type,
      size_bytes: record.size_bytes,
      inline: record.inline,
      download_url: "/api/v1/attachments/#{record.id}/download"
    }
  end
end
