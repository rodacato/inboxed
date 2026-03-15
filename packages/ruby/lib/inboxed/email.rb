# frozen_string_literal: true

module Inboxed
  class Email
    attr_reader :id, :from, :to, :subject, :body_text, :body_html, :received_at

    def initialize(attrs)
      @id = attrs["id"]
      @from = attrs["from"]
      @to = Array(attrs["to"])
      @subject = attrs["subject"]
      @body_text = attrs["body_text"]
      @body_html = attrs["body_html"]
      @received_at = attrs["received_at"]
    end
  end
end
