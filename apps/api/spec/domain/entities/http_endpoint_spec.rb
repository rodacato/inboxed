# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Entities::HttpEndpoint do
  def build(attrs = {})
    described_class.new({
      id: SecureRandom.uuid,
      project_id: SecureRandom.uuid,
      endpoint_type: "webhook",
      token: "wh_test123",
      allowed_methods: %w[POST],
      max_body_bytes: 262_144,
      created_at: Time.current
    }.merge(attrs))
  end

  describe "type predicates" do
    it "identifies webhook" do
      ep = build(endpoint_type: "webhook")
      expect(ep.webhook?).to be true
      expect(ep.form?).to be false
      expect(ep.heartbeat?).to be false
    end

    it "identifies form" do
      ep = build(endpoint_type: "form")
      expect(ep.form?).to be true
    end

    it "identifies heartbeat" do
      ep = build(endpoint_type: "heartbeat")
      expect(ep.heartbeat?).to be true
    end
  end

  describe "#accepts_method?" do
    it "returns true for allowed methods" do
      ep = build(allowed_methods: %w[POST PUT])
      expect(ep.accepts_method?("POST")).to be true
      expect(ep.accepts_method?("PUT")).to be true
      expect(ep.accepts_method?("GET")).to be false
    end
  end

  describe "#accepts_ip?" do
    it "returns true when allowlist is empty" do
      ep = build(allowed_ips: [])
      expect(ep.accepts_ip?("1.2.3.4")).to be true
    end

    it "returns true for listed IP" do
      ep = build(allowed_ips: ["10.0.0.1", "10.0.0.2"])
      expect(ep.accepts_ip?("10.0.0.1")).to be true
    end

    it "returns false for unlisted IP" do
      ep = build(allowed_ips: ["10.0.0.1"])
      expect(ep.accepts_ip?("99.99.99.99")).to be false
    end
  end

  describe "optional configs" do
    it "accepts form_config for form endpoints" do
      ep = build(
        endpoint_type: "form",
        form_config: Inboxed::ValueObjects::FormConfig.new(
          response_mode: "redirect",
          redirect_url: "https://example.com/thanks"
        )
      )
      expect(ep.form_config.response_mode).to eq("redirect")
    end

    it "accepts heartbeat_config for heartbeat endpoints" do
      ep = build(
        endpoint_type: "heartbeat",
        heartbeat_config: Inboxed::ValueObjects::HeartbeatConfig.new(
          expected_interval_seconds: 300,
          status: "healthy",
          last_ping_at: 1.minute.ago
        )
      )
      expect(ep.heartbeat_config.evaluate).to eq(:healthy)
    end
  end
end
