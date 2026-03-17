# frozen_string_literal: true

module Inboxed
  module Services
    class ReceiveInboundEmail
      MAX_FAN_OUT = 10

      def call(envelope_to:, envelope_from:, raw_source:)
        inboxes = InboxRecord.where(address: envelope_to)
                             .includes(:project)
                             .limit(MAX_FAN_OUT)

        return {delivered_to: 0, redacted: 0} if inboxes.empty?

        delivered = 0
        redacted = 0

        inboxes.each do |inbox|
          if Inboxed::Features.enabled?(:inbound_email)
            ReceiveEmailJob.perform_later(
              project_id: inbox.project_id,
              envelope_from: envelope_from,
              envelope_to: [envelope_to],
              raw_source: raw_source,
              source_type: "inbound"
            )
            delivered += 1
          else
            ReceiveEmailJob.perform_later(
              project_id: inbox.project_id,
              envelope_from: envelope_from,
              envelope_to: [envelope_to],
              raw_source: redact_email_source(raw_source, envelope_from),
              source_type: "inbound_redacted"
            )
            redacted += 1
          end
        end

        {delivered_to: delivered, redacted: redacted}
      end

      private

      def redact_email_source(raw_source, envelope_from)
        parsed = Mail.new(raw_source)
        redacted = Mail.new
        redacted.from = parsed.from
        redacted.to = parsed.to
        redacted.subject = parsed.subject
        redacted.date = parsed.date
        redacted.message_id = parsed.message_id
        redacted.body = <<~TEXT
          [Inboxed] This email was received from #{envelope_from} but its content
          is not available because inbound email is not enabled for this project.

          To view the full content of inbound emails, enable the inbound email
          feature flag:

            INBOXED_FEATURE_INBOUND_EMAIL=true

          What you can see:
            - From: #{parsed.from&.first}
            - Subject: #{parsed.subject}
            - Received at: #{Time.current.utc.iso8601}

          The original email contained #{parsed.attachments.size} attachment(s)
          and was #{raw_source.bytesize} bytes.
        TEXT
        redacted.to_s
      end
    end
  end
end
