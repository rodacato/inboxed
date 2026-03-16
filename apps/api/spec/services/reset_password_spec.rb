# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::ResetPassword do
  subject(:service) { described_class.new }

  describe "with valid token and password" do
    it "resets the password" do
      user = UserRecord.create!(
        email: "reset@test.dev",
        password: "oldpassword1",
        password_reset_token: "valid-reset-token",
        password_reset_sent_at: 30.minutes.ago
      )

      result = service.call(token: "valid-reset-token", password: "newpassword1")

      expect(result.success?).to be true
      user.reload
      expect(user.authenticate("newpassword1")).to eq(user)
      expect(user.password_reset_sent_at).to be_nil
    end
  end

  describe "with invalid token" do
    it "returns failure" do
      result = service.call(token: "bad-token", password: "newpassword1")

      expect(result.success?).to be false
      expect(result.errors).to include("Invalid or expired reset token")
    end
  end

  describe "with expired token (>1h)" do
    it "returns failure" do
      UserRecord.create!(
        email: "expiredreset@test.dev",
        password: "oldpassword1",
        password_reset_token: "expired-reset-token",
        password_reset_sent_at: 2.hours.ago
      )

      result = service.call(token: "expired-reset-token", password: "newpassword1")

      expect(result.success?).to be false
      expect(result.errors).to include("Token expired")
    end
  end

  describe "with short password" do
    it "returns failure" do
      UserRecord.create!(
        email: "shortpw@test.dev",
        password: "oldpassword1",
        password_reset_token: "short-pw-token",
        password_reset_sent_at: 30.minutes.ago
      )

      result = service.call(token: "short-pw-token", password: "short")

      expect(result.success?).to be false
      expect(result.errors).to include("Password must be at least 8 characters")
    end
  end
end
