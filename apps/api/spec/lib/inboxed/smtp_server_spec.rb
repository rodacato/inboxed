# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::SmtpServer do
  subject(:server) { described_class.new }

  before { ActiveJob::Base.queue_adapter = :test }

  let!(:project) do
    ProjectRecord.create!(
      id: SecureRandom.uuid,
      name: "SMTP Test",
      slug: "smtp-test"
    )
  end

  let(:token) { SecureRandom.hex(32) }

  let!(:api_key) do
    ApiKeyRecord.create!(
      id: SecureRandom.uuid,
      project: project,
      label: "test",
      token_prefix: token[0, 8],
      token_digest: BCrypt::Password.create(token)
    )
  end

  after do
    server.stop
  rescue
    nil
  end

  describe "#on_auth_event" do
    let(:ctx) { {} }

    it "returns the API key ID on valid credentials" do
      result = server.on_auth_event(ctx, "", "", token)
      expect(result).to eq(api_key.id)
    end

    it "raises Smtpd535Exception on invalid credentials" do
      expect {
        server.on_auth_event(ctx, "", "", "invalid-token")
      }.to raise_error(MidiSmtpServer::Smtpd535Exception)
    end

    it "raises Smtpd535Exception on blank credentials" do
      expect {
        server.on_auth_event(ctx, "", "", "")
      }.to raise_error(MidiSmtpServer::Smtpd535Exception)
    end
  end

  describe "#on_message_data_event" do
    let(:raw_source) do
      <<~EMAIL
        From: sender@app.test
        To: user@example.com
        Subject: Your code is 123456

        Your verification code: 123456
      EMAIL
    end

    let(:ctx) do
      {
        server: {authorization_id: api_key.id},
        envelope: {
          from: "sender@app.test",
          to: ["user@example.com"]
        },
        message: {data: raw_source}
      }
    end

    it "enqueues a ReceiveEmailJob" do
      expect {
        server.on_message_data_event(ctx)
      }.to have_enqueued_job(ReceiveEmailJob).with(
        project_id: project.id,
        api_key_id: api_key.id,
        envelope_from: "sender@app.test",
        envelope_to: ["user@example.com"],
        raw_source: raw_source,
        source_type: "relay"
      )
    end

    it "strips angle brackets from envelope addresses" do
      ctx[:envelope][:from] = "<sender@app.test>"
      ctx[:envelope][:to] = ["<user@example.com>", "<other@example.com>"]

      expect {
        server.on_message_data_event(ctx)
      }.to have_enqueued_job(ReceiveEmailJob).with(
        project_id: project.id,
        api_key_id: api_key.id,
        envelope_from: "sender@app.test",
        envelope_to: ["user@example.com", "other@example.com"],
        raw_source: raw_source,
        source_type: "relay"
      )
    end

    it "reads authorization_id from context (not authenticated)" do
      # This is the bug we fixed: midi-smtp-server stores the return value
      # of on_auth_event in ctx[:server][:authorization_id], not in
      # ctx[:server][:authenticated] (which is a timestamp).
      ctx_with_timestamp = {
        server: {
          authenticated: Time.now.utc,
          authorization_id: api_key.id
        },
        envelope: {from: "a@b.com", to: ["c@d.com"]},
        message: {data: raw_source}
      }

      expect {
        server.on_message_data_event(ctx_with_timestamp)
      }.to have_enqueued_job(ReceiveEmailJob)
    end

    it "does not enqueue when authorization_id is nil" do
      ctx[:server][:authorization_id] = nil

      expect {
        server.on_message_data_event(ctx)
      }.not_to have_enqueued_job(ReceiveEmailJob)
    end

    it "does not enqueue when API key is not found" do
      ctx[:server][:authorization_id] = SecureRandom.uuid

      expect {
        server.on_message_data_event(ctx)
      }.not_to have_enqueued_job(ReceiveEmailJob)
    end
  end

  describe "#on_rcpt_to_event" do
    it "accepts any recipient (catch-all)" do
      ctx = {envelope: {to: []}}
      result = server.on_rcpt_to_event(ctx, "anyone@any-domain.com")
      expect(result).to eq("anyone@any-domain.com")
    end
  end

  describe "#on_mail_from_event" do
    it "accepts any sender" do
      result = server.on_mail_from_event({}, "sender@app.test")
      expect(result).to eq("sender@app.test")
    end
  end
end
