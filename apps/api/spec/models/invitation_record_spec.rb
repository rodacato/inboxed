# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvitationRecord, type: :model do
  let(:org) { OrganizationRecord.create!(name: "Test Org", slug: "invite-test-#{SecureRandom.hex(4)}") }
  let(:inviter) { UserRecord.create!(email: "inviter@test.dev", password: "password123") }

  def create_invitation(overrides = {})
    InvitationRecord.create!({
      organization: org,
      email: "invited@test.dev",
      token: SecureRandom.urlsafe_base64(32),
      role: "member",
      invited_by: inviter,
      expires_at: 7.days.from_now,
      accepted_at: nil
    }.merge(overrides))
  end

  describe "#expired?" do
    it "returns true when expires_at is in the past" do
      invitation = create_invitation(expires_at: 1.day.ago)
      expect(invitation.expired?).to be true
    end

    it "returns false when expires_at is in the future" do
      invitation = create_invitation(expires_at: 7.days.from_now)
      expect(invitation.expired?).to be false
    end
  end

  describe "#accepted?" do
    it "returns true when accepted_at is set" do
      invitation = create_invitation(accepted_at: Time.current)
      expect(invitation.accepted?).to be true
    end

    it "returns false when accepted_at is nil" do
      invitation = create_invitation(accepted_at: nil)
      expect(invitation.accepted?).to be false
    end
  end

  describe ".pending" do
    it "excludes accepted invitations" do
      pending_inv = create_invitation(accepted_at: nil, token: SecureRandom.urlsafe_base64(32))
      accepted_inv = create_invitation(accepted_at: Time.current, email: "accepted@test.dev", token: SecureRandom.urlsafe_base64(32))

      results = InvitationRecord.pending
      expect(results).to include(pending_inv)
      expect(results).not_to include(accepted_inv)
    end

    it "excludes expired invitations" do
      active_inv = create_invitation(expires_at: 7.days.from_now, token: SecureRandom.urlsafe_base64(32))
      expired_inv = create_invitation(expires_at: 1.day.ago, email: "expired@test.dev", token: SecureRandom.urlsafe_base64(32))

      results = InvitationRecord.pending
      expect(results).to include(active_inv)
      expect(results).not_to include(expired_inv)
    end
  end

  describe ".expired" do
    it "includes only expired invitations" do
      active_inv = create_invitation(expires_at: 7.days.from_now, token: SecureRandom.urlsafe_base64(32))
      expired_inv = create_invitation(expires_at: 1.day.ago, email: "expired@test.dev", token: SecureRandom.urlsafe_base64(32))

      results = InvitationRecord.expired
      expect(results).to include(expired_inv)
      expect(results).not_to include(active_inv)
    end
  end
end
