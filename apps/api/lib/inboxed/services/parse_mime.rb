# frozen_string_literal: true

require "mail"

module Inboxed
  module Services
    class ParseMime
      ParsedEmail = Struct.new(
        :from, :to, :cc, :subject,
        :body_html, :body_text,
        :headers, :attachments,
        keyword_init: true
      )

      def call(raw_source)
        mail = Mail.new(raw_source)

        ParsedEmail.new(
          from: extract_from(mail),
          to: extract_addresses(mail.to),
          cc: extract_addresses(mail.cc),
          subject: mail.subject,
          body_html: extract_html(mail),
          body_text: extract_text(mail),
          headers: extract_headers(mail),
          attachments: extract_attachments(mail)
        )
      end

      private

      def extract_html(mail)
        if mail.html_part
          mail.html_part.decoded
        elsif mail.content_type&.include?("text/html")
          mail.body.decoded
        end
      end

      def extract_text(mail)
        if mail.text_part
          mail.text_part.decoded
        elsif mail.content_type&.include?("text/plain") || !mail.multipart?
          mail.body.decoded
        end
      end

      def extract_attachments(mail)
        mail.attachments.map do |att|
          {
            filename: att.filename || "unnamed",
            content_type: att.content_type.split(";").first,
            size_bytes: att.decoded.bytesize,
            content: att.decoded,
            content_id: att.content_id&.gsub(/[<>]/, ""),
            inline: att.content_disposition&.start_with?("inline") || false
          }
        end
      end

      def extract_from(mail)
        mail.from&.first || mail.header["From"]&.to_s || "unknown@unknown"
      end

      def extract_addresses(field)
        Array(field).map(&:to_s)
      end

      def extract_headers(mail)
        mail.header.fields.each_with_object({}) do |field, hash|
          hash[field.name] = field.value
        end
      end
    end
  end
end
