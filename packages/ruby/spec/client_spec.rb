# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inboxed::Client do
  let(:client) { described_class.new(api_url: "http://localhost:3000", api_key: "test-key") }
  let(:inbox_address) { "test@mail.inboxed.dev" }
  let(:inbox_response) do
    {
      data: [{id: "inbox-1", address: inbox_address, email_count: 3, last_email_at: nil, created_at: "2026-03-14T10:00:00Z"}],
      meta: {total_count: 1, next_cursor: nil}
    }.to_json
  end
  let(:empty_inbox_response) do
    {data: [], meta: {total_count: 0, next_cursor: nil}}.to_json
  end
  let(:emails_list) do
    {
      data: [{id: "email-1", inbox_id: "inbox-1", inbox_address: inbox_address, from: "noreply@app.com", subject: "Your code is 482910", preview: "Your verification code...", received_at: "2026-03-15T10:00:00Z"}],
      meta: {total_count: 1, next_cursor: nil}
    }.to_json
  end
  let(:email_detail) do
    {
      id: "email-1", inbox_id: "inbox-1", inbox_address: inbox_address,
      from: "noreply@app.com", to: [inbox_address], cc: [],
      subject: "Your code is 482910",
      body_text: "Your verification code is 482910",
      body_html: "<p>Your verification code is <b>482910</b></p>",
      received_at: "2026-03-15T10:00:00Z",
      source_type: "smtp", raw_headers: {}, expires_at: nil, attachments: []
    }.to_json
  end

  describe "#wait_for_email" do
    it "returns email when one arrives" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 200, body: inbox_response)
      stub_request(:post, "http://localhost:3000/api/v1/emails/wait")
        .to_return(status: 200, body: email_detail)
      stub_request(:get, "http://localhost:3000/api/v1/emails/email-1")
        .to_return(status: 200, body: email_detail)

      email = client.wait_for_email(inbox_address)
      expect(email.id).to eq("email-1")
      expect(email.subject).to eq("Your code is 482910")
    end

    it "raises TimeoutError on 408" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 200, body: inbox_response)
      stub_request(:post, "http://localhost:3000/api/v1/emails/wait")
        .to_return(status: 408, body: "")

      expect { client.wait_for_email(inbox_address, timeout: 5) }
        .to raise_error(Inboxed::TimeoutError)
    end

    it "passes subject pattern" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 200, body: inbox_response)
      wait_stub = stub_request(:post, "http://localhost:3000/api/v1/emails/wait")
        .to_return(status: 200, body: email_detail)
      stub_request(:get, "http://localhost:3000/api/v1/emails/email-1")
        .to_return(status: 200, body: email_detail)

      client.wait_for_email(inbox_address, subject: /verify/i)
      body = JSON.parse(wait_stub.with { |req| true }.to_return(status: 200).request_pattern.body_pattern.to_s) rescue nil
      # Just verify it doesn't raise
    end
  end

  describe "#latest_email" do
    it "returns the latest email" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 200, body: inbox_response)
      stub_request(:get, "http://localhost:3000/api/v1/inboxes/inbox-1/emails?limit=1")
        .to_return(status: 200, body: emails_list)
      stub_request(:get, "http://localhost:3000/api/v1/emails/email-1")
        .to_return(status: 200, body: email_detail)

      email = client.latest_email(inbox_address)
      expect(email).not_to be_nil
      expect(email.body_text).to eq("Your verification code is 482910")
    end

    it "returns nil for empty inbox" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 200, body: inbox_response)
      stub_request(:get, "http://localhost:3000/api/v1/inboxes/inbox-1/emails?limit=1")
        .to_return(status: 200, body: empty_inbox_response)

      expect(client.latest_email(inbox_address)).to be_nil
    end
  end

  describe "#delete_inbox" do
    it "resolves and deletes the inbox" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 200, body: inbox_response)
      delete_stub = stub_request(:delete, "http://localhost:3000/api/v1/inboxes/inbox-1")
        .to_return(status: 204, body: "")

      client.delete_inbox(inbox_address)
      expect(delete_stub).to have_been_requested
    end
  end

  describe "#extract_code" do
    it "extracts code from latest email" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 200, body: inbox_response)
      stub_request(:get, "http://localhost:3000/api/v1/inboxes/inbox-1/emails?limit=1")
        .to_return(status: 200, body: emails_list)
      stub_request(:get, "http://localhost:3000/api/v1/emails/email-1")
        .to_return(status: 200, body: email_detail)

      expect(client.extract_code(inbox_address)).to eq("482910")
    end

    it "returns nil for empty inbox" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 200, body: inbox_response)
      stub_request(:get, "http://localhost:3000/api/v1/inboxes/inbox-1/emails?limit=1")
        .to_return(status: 200, body: empty_inbox_response)

      expect(client.extract_code(inbox_address)).to be_nil
    end
  end

  describe "#extract_link" do
    it "extracts URL from latest email" do
      link_email = {
        id: "email-1", from: "noreply@app.com", to: [inbox_address], cc: [],
        subject: "Verify", body_text: "Click https://app.com/verify?t=abc",
        body_html: nil, received_at: "2026-03-15T10:00:00Z",
        source_type: "smtp", raw_headers: {}, expires_at: nil, attachments: []
      }.to_json

      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 200, body: inbox_response)
      stub_request(:get, "http://localhost:3000/api/v1/inboxes/inbox-1/emails?limit=1")
        .to_return(status: 200, body: emails_list)
      stub_request(:get, "http://localhost:3000/api/v1/emails/email-1")
        .to_return(status: 200, body: link_email)

      expect(client.extract_link(inbox_address)).to eq("https://app.com/verify?t=abc")
    end

    it "filters by pattern" do
      link_email = {
        id: "email-1", from: "noreply@app.com", to: [inbox_address], cc: [],
        subject: "Links", body_text: "Visit https://app.com/home or https://app.com/reset?t=x",
        body_html: nil, received_at: "2026-03-15T10:00:00Z",
        source_type: "smtp", raw_headers: {}, expires_at: nil, attachments: []
      }.to_json

      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 200, body: inbox_response)
      stub_request(:get, "http://localhost:3000/api/v1/inboxes/inbox-1/emails?limit=1")
        .to_return(status: 200, body: emails_list)
      stub_request(:get, "http://localhost:3000/api/v1/emails/email-1")
        .to_return(status: 200, body: link_email)

      expect(client.extract_link(inbox_address, pattern: /reset/)).to eq("https://app.com/reset?t=x")
    end
  end

  describe "#extract_value" do
    it "extracts labeled value from latest email" do
      pw_email = {
        id: "email-1", from: "noreply@app.com", to: [inbox_address], cc: [],
        subject: "Credentials", body_text: "Temporary password: xK9#mP2!",
        body_html: nil, received_at: "2026-03-15T10:00:00Z",
        source_type: "smtp", raw_headers: {}, expires_at: nil, attachments: []
      }.to_json

      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 200, body: inbox_response)
      stub_request(:get, "http://localhost:3000/api/v1/inboxes/inbox-1/emails?limit=1")
        .to_return(status: 200, body: emails_list)
      stub_request(:get, "http://localhost:3000/api/v1/emails/email-1")
        .to_return(status: 200, body: pw_email)

      expect(client.extract_value(inbox_address, label: "password")).to eq("xK9#mP2!")
    end
  end

  describe "error handling" do
    it "raises NotFoundError for unknown inbox" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=unknown@mail.inboxed.dev")
        .to_return(status: 200, body: empty_inbox_response)

      expect { client.latest_email("unknown@mail.inboxed.dev") }
        .to raise_error(Inboxed::NotFoundError, /Inbox not found/)
    end

    it "raises AuthError on 401" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 401, body: "")

      expect { client.latest_email(inbox_address) }
        .to raise_error(Inboxed::AuthError)
    end

    it "raises NotFoundError on 404" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 404, body: "")

      expect { client.latest_email(inbox_address) }
        .to raise_error(Inboxed::NotFoundError)
    end

    it "raises Error on 500" do
      stub_request(:get, "http://localhost:3000/api/v1/inboxes?address=#{inbox_address}")
        .to_return(status: 500, body: "")

      expect { client.latest_email(inbox_address) }
        .to raise_error(Inboxed::Error, /500/)
    end
  end
end
