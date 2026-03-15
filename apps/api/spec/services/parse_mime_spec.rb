# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::ParseMime do
  subject(:parser) { described_class.new }

  describe "#call" do
    context "with a plain text email" do
      let(:raw) do
        <<~EMAIL
          From: sender@test.com
          To: recipient@example.com
          Subject: Hello World

          This is the body.
        EMAIL
      end

      it "extracts from, to, subject, and body_text" do
        result = parser.call(raw)
        expect(result.from).to eq("sender@test.com")
        expect(result.to).to eq(["recipient@example.com"])
        expect(result.subject).to eq("Hello World")
        expect(result.body_text).to include("This is the body.")
      end

      it "has nil body_html" do
        result = parser.call(raw)
        expect(result.body_html).to be_nil
      end
    end

    context "with a multipart email" do
      let(:raw) do
        mail = Mail.new do
          from "sender@test.com"
          to "recipient@example.com"
          subject "Multipart test"

          text_part do
            body "Plain text version"
          end

          html_part do
            content_type "text/html; charset=UTF-8"
            body "<h1>HTML version</h1>"
          end
        end
        mail.to_s
      end

      it "extracts both html and text" do
        result = parser.call(raw)
        expect(result.body_text).to include("Plain text version")
        expect(result.body_html).to include("<h1>HTML version</h1>")
      end
    end

    context "with attachments" do
      let(:raw) do
        mail = Mail.new do
          from "sender@test.com"
          to "recipient@example.com"
          subject "With attachment"
          body "See attached"

          add_file filename: "test.txt", content: "file content here"
        end
        mail.to_s
      end

      it "extracts attachment metadata" do
        result = parser.call(raw)
        expect(result.attachments.size).to eq(1)

        att = result.attachments.first
        expect(att[:filename]).to eq("test.txt")
        expect(att[:size_bytes]).to be > 0
        expect(att[:content]).to eq("file content here")
      end
    end

    context "with multiple recipients and CC" do
      let(:raw) do
        <<~EMAIL
          From: sender@test.com
          To: a@example.com, b@example.com
          Cc: c@example.com
          Subject: Multi

          Body
        EMAIL
      end

      it "extracts all addresses" do
        result = parser.call(raw)
        expect(result.to).to contain_exactly("a@example.com", "b@example.com")
        expect(result.cc).to eq(["c@example.com"])
      end
    end

    context "with missing From header" do
      let(:raw) do
        <<~EMAIL
          To: recipient@example.com
          Subject: No from

          Body
        EMAIL
      end

      it "defaults to unknown@unknown" do
        result = parser.call(raw)
        expect(result.from).to eq("unknown@unknown")
      end
    end
  end
end
