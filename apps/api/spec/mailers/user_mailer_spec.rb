# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#verification" do
    let(:user) do
      UserRecord.create!(
        email: "verify@test.dev",
        password: "password123",
        verification_token: "test-verification-token",
        verification_sent_at: Time.current
      )
    end

    let(:mail) { described_class.verification(user) }

    it "has the correct subject" do
      expect(mail.subject).to eq("Verify your Inboxed account")
    end

    it "sends to the user email" do
      expect(mail.to).to eq(["verify@test.dev"])
    end

    it "includes the verification URL in the body" do
      expect(mail.body.encoded).to include("test-verification-token")
      expect(mail.body.encoded).to include("/auth/verify?token=")
    end
  end

  describe "#password_reset" do
    let(:user) do
      UserRecord.create!(
        email: "reset@test.dev",
        password: "password123",
        verified_at: Time.current,
        password_reset_token: "test-reset-token",
        password_reset_sent_at: Time.current
      )
    end

    let(:mail) { described_class.password_reset(user) }

    it "has the correct subject" do
      expect(mail.subject).to eq("Reset your Inboxed password")
    end

    it "sends to the user email" do
      expect(mail.to).to eq(["reset@test.dev"])
    end

    it "includes the reset URL in the body" do
      expect(mail.body.encoded).to include("/reset-password?token=")
    end
  end
end
