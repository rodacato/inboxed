# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /hooks/inbound", type: :request do
  include ActiveJob::TestHelper

  let(:webhook_secret) { "test-webhook-secret-12345" }

  before { ActiveJob::Base.queue_adapter = :test }

  let!(:project) do
    ProjectRecord.create!(
      id: SecureRandom.uuid,
      name: "Test Project",
      slug: "test-inbound",
      default_ttl_hours: 24
    )
  end

  let(:inbox_address) { "test@mail.notdefined.dev" }

  let!(:inbox) do
    InboxRecord.create!(
      id: SecureRandom.uuid,
      project: project,
      address: inbox_address,
      email_count: 0
    )
  end

  let(:raw_email) do
    <<~EMAIL
      From: sender@gmail.com
      To: #{inbox_address}
      Subject: Verification code
      Date: #{Time.current.rfc2822}
      Message-ID: <msg123@gmail.com>

      Your code is 123456.
    EMAIL
  end

  let(:valid_headers) do
    {
      "Authorization" => "Bearer #{webhook_secret}",
      "Content-Type" => "message/rfc822",
      "X-Envelope-From" => "sender@gmail.com",
      "X-Envelope-To" => inbox_address
    }
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("INBOUND_WEBHOOK_SECRET").and_return(webhook_secret)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("INBOUND_WEBHOOK_SECRET").and_return(webhook_secret)
  end

  describe "authentication" do
    it "returns 401 without Authorization header" do
      post "/hooks/inbound", params: raw_email, headers: valid_headers.except("Authorization")

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to eq("unauthorized")
    end

    it "returns 401 with invalid secret" do
      post "/hooks/inbound", params: raw_email, headers: valid_headers.merge("Authorization" => "Bearer wrong-secret")

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 503 when INBOUND_WEBHOOK_SECRET is not configured" do
      allow(ENV).to receive(:[]).with("INBOUND_WEBHOOK_SECRET").and_return(nil)
      allow(ENV).to receive(:fetch).with("INBOUND_WEBHOOK_SECRET").and_return(nil)

      post "/hooks/inbound", params: raw_email, headers: valid_headers

      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe "header validation" do
    it "returns 422 without X-Envelope-To header" do
      post "/hooks/inbound", params: raw_email, headers: valid_headers.except("X-Envelope-To")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to eq("missing X-Envelope-To header")
    end
  end

  describe "successful delivery" do
    before do
      allow(Inboxed::Features).to receive(:enabled?).and_call_original
      allow(Inboxed::Features).to receive(:enabled?).with(:inbound_email).and_return(true)
    end

    it "returns 202 with delivery counts" do
      post "/hooks/inbound", params: raw_email, headers: valid_headers

      expect(response).to have_http_status(:accepted)
      data = response.parsed_body["data"]
      expect(data["delivered_to"]).to eq(1)
      expect(data["redacted"]).to eq(0)
    end

    it "enqueues a ReceiveEmailJob" do
      expect {
        post "/hooks/inbound", params: raw_email, headers: valid_headers
      }.to have_enqueued_job(ReceiveEmailJob)
    end

    it "returns 202 with zero counts for non-matching address" do
      post "/hooks/inbound", params: raw_email,
        headers: valid_headers.merge("X-Envelope-To" => "nobody@mail.notdefined.dev")

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["data"]["delivered_to"]).to eq(0)
    end
  end

  describe "redacted delivery" do
    before do
      allow(Inboxed::Features).to receive(:enabled?).and_call_original
      allow(Inboxed::Features).to receive(:enabled?).with(:inbound_email).and_return(false)
    end

    it "returns redacted count when feature is disabled" do
      post "/hooks/inbound", params: raw_email, headers: valid_headers

      expect(response).to have_http_status(:accepted)
      data = response.parsed_body["data"]
      expect(data["delivered_to"]).to eq(0)
      expect(data["redacted"]).to eq(1)
    end
  end
end
