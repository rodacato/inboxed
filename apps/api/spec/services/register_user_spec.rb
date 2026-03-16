# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::RegisterUser do
  let(:event_store) { double("EventStore", publish: nil) }
  subject(:service) { described_class.new(event_store: event_store) }

  after do
    ENV.delete("REGISTRATION_MODE")
    ENV.delete("OUTBOUND_SMTP_HOST")
  end

  describe "with REGISTRATION_MODE=open" do
    before { ENV["REGISTRATION_MODE"] = "open" }

    it "creates user, org, membership, and project" do
      result = service.call(email: "open@test.dev", password: "password123")

      expect(result.success?).to be true
      expect(result.user).to be_persisted

      user = result.user
      expect(user.organizations.count).to eq(1)
      expect(MembershipRecord.where(user: user).count).to eq(1)

      org = user.organizations.first
      expect(ProjectRecord.where(organization: org).count).to eq(1)
    end
  end

  describe "with REGISTRATION_MODE=closed and no token" do
    before { ENV["REGISTRATION_MODE"] = "closed" }

    it "raises RegistrationClosed" do
      expect {
        service.call(email: "closed@test.dev", password: "password123")
      }.to raise_error(Inboxed::Services::RegisterUser::RegistrationClosed)
    end
  end

  describe "with invitation_token" do
    before { ENV["REGISTRATION_MODE"] = "closed" }

    let(:org) { OrganizationRecord.create!(name: "Invite Org", slug: "invite-org-#{SecureRandom.hex(4)}") }
    let(:inviter) { UserRecord.create!(email: "inviter@test.dev", password: "password123") }

    it "creates user and membership in existing org" do
      invitation = InvitationRecord.create!(
        organization: org,
        email: "invited@test.dev",
        token: "valid-token-123",
        role: "member",
        invited_by: inviter,
        expires_at: 7.days.from_now
      )

      result = service.call(email: "invited@test.dev", password: "password123", invitation_token: "valid-token-123")

      expect(result.success?).to be true
      expect(result.user).to be_persisted
      expect(MembershipRecord.where(user: result.user, organization: org).count).to eq(1)
      expect(invitation.reload.accepted?).to be true
    end

    it "raises InvitationExpired for expired invitation" do
      InvitationRecord.create!(
        organization: org,
        email: "expired@test.dev",
        token: "expired-token-123",
        role: "member",
        invited_by: inviter,
        expires_at: 1.day.ago
      )

      expect {
        service.call(email: "expired@test.dev", password: "password123", invitation_token: "expired-token-123")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "auto-verification behavior" do
    before { ENV["REGISTRATION_MODE"] = "open" }

    it "auto-verifies when OUTBOUND_SMTP_HOST is not set" do
      ENV.delete("OUTBOUND_SMTP_HOST")

      result = service.call(email: "autoverify@test.dev", password: "password123")

      expect(result.user.verified?).to be true
    end

    it "does NOT auto-verify when OUTBOUND_SMTP_HOST is set" do
      ENV["OUTBOUND_SMTP_HOST"] = "smtp.example.com"

      result = service.call(email: "noverify@test.dev", password: "password123")

      expect(result.user.verified?).to be false
    end
  end
end
