# frozen_string_literal: true

module Inboxed
  module Extract
    module_function

    # Extract a verification code from email body.
    # Default pattern matches 4-8 digit codes. Returns the last match.
    def code(body_text, body_html, pattern: nil)
      text = body_text || strip_html(body_html || "")
      return nil if text.empty?

      regex = pattern ? Regexp.new(pattern) : /\b\d{4,8}\b/
      matches = text.scan(regex)
      matches.empty? ? nil : matches.last
    end

    # Extract URLs from email body.
    # Searches body_text first, falls back to href parsing in body_html.
    def link(body_text, body_html)
      if body_text
        return body_text.scan(%r{https?://[^\s<>")\]]+})
      end

      if body_html
        return body_html.scan(/href=["'](https?:\/\/[^"']+)["']/i).flatten
      end

      []
    end

    # Extract a labeled value from email body.
    # Case-insensitive label matching.
    def value(body_text, body_html, label:, pattern: nil)
      text = body_text || strip_html(body_html || "")
      return nil if text.empty?

      value_capture = pattern || '\S+'
      escaped_label = Regexp.escape(label)
      regex = /#{escaped_label}[:#\s]+\s*(#{value_capture})/i
      match = text.match(regex)
      match ? match[1] : nil
    end

    # Strip HTML tags to get plain text.
    def strip_html(html)
      html
        .gsub(/<br\s*\/?>/i, "\n")
        .gsub(%r{</p>}i, "\n\n")
        .gsub(/<[^>]+>/, "")
        .gsub("&nbsp;", " ")
        .gsub("&amp;", "&")
        .gsub("&lt;", "<")
        .gsub("&gt;", ">")
        .strip
    end
  end
end
