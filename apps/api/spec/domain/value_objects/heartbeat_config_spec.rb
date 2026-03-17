# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::ValueObjects::HeartbeatConfig do
  describe "#evaluate" do
    let(:interval) { 300 } # 5 minutes

    def build(status:, last_ping_at:)
      described_class.new(
        expected_interval_seconds: interval,
        status: status,
        last_ping_at: last_ping_at
      )
    end

    it "returns :pending when no ping received" do
      config = described_class.new(
        expected_interval_seconds: interval,
        status: "pending"
      )
      expect(config.evaluate).to eq(:pending)
    end

    it "returns :healthy when ping is within interval" do
      config = build(status: "healthy", last_ping_at: 2.minutes.ago)
      expect(config.evaluate).to eq(:healthy)
    end

    it "returns :late when ping is between 1x and 2x interval" do
      config = build(status: "healthy", last_ping_at: 6.minutes.ago)
      expect(config.evaluate).to eq(:late)
    end

    it "returns :down when ping is beyond 2x interval" do
      config = build(status: "healthy", last_ping_at: 11.minutes.ago)
      expect(config.evaluate).to eq(:down)
    end

    it "returns :healthy at exact interval boundary" do
      config = build(status: "healthy", last_ping_at: 4.minutes.ago)
      expect(config.evaluate).to eq(:healthy)
    end
  end

  it "rejects non-positive interval" do
    expect {
      described_class.new(expected_interval_seconds: 0, status: "pending")
    }.to raise_error(Dry::Struct::Error)
  end
end
