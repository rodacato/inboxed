# frozen_string_literal: true

module Inboxed
  module Repositories
    class EmailRepository
      def save(id:, inbox_id:, parsed:, raw_source:, source_type:, expires_at:)
        EmailRecord.create!(
          id: id,
          inbox_id: inbox_id,
          from_address: parsed.from,
          to_addresses: parsed.to,
          cc_addresses: parsed.cc,
          subject: parsed.subject,
          body_html: parsed.body_html,
          body_text: parsed.body_text,
          raw_headers: parsed.headers,
          raw_source: raw_source,
          source_type: source_type,
          received_at: Time.current,
          expires_at: expires_at
        )
      end

      def save_attachments(email_id, attachments)
        attachments.each do |att|
          AttachmentRecord.create!(
            id: SecureRandom.uuid,
            email_id: email_id,
            filename: att[:filename],
            content_type: att[:content_type],
            size_bytes: att[:size_bytes],
            content: att[:content],
            content_id: att[:content_id],
            inline: att[:inline] || false
          )
        end
      end
    end
  end
end
