# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::VerifyUser do
  let(:event_store) { double("EventStore", publish: nil) }
  subject(:service) { described_class.new(event_store: event_store) }

  describe "with valid token" do
    it "verifies the user and returns success" do
      user = UserRecord.create!(
        email: "verify@test.dev",
        password: "password123",
        verification_token: "valid-token",
        verification_sent_at: 1.hour.ago
      )

      result = service.call(token: "valid-token")

      expect(result.success?).to be true
      expect(user.reload.verified?).to be true
      expect(user.verification_token).to be_nil
    end
  end

  describe "with invalid token" do
    it "returns failure" do
      result = service.call(token: "nonexistent-token")

      expect(result.success?).to be false
      expect(result.errors).to include("Invalid or expired verification token")
    end
  end

  describe "with expired token (>24h)" do
    it "returns failure" do
      UserRecord.create!(
        email: "expired@test.dev",
        password: "password123",
        verification_token: "expired-token",
        verification_sent_at: 25.hours.ago
      )

      result = service.call(token: "expired-token")

      expect(result.success?).to be false
      expect(result.errors).to include("Token expired")
    end
  end
end
