# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvitationMailer, type: :mailer do
  describe "#invite" do
    let(:org) do
      OrganizationRecord.create!(
        name: "Acme Corp",
        slug: "acme-corp-#{SecureRandom.hex(4)}",
        trial_ends_at: nil
      )
    end

    let(:inviter) do
      UserRecord.create!(
        email: "inviter@test.dev",
        password: "password123",
        verified_at: Time.current
      )
    end

    let(:invitation) do
      InvitationRecord.create!(
        organization: org,
        email: "invitee@test.dev",
        role: "member",
        token: "test-invite-token",
        invited_by: inviter,
        expires_at: 7.days.from_now
      )
    end

    let(:mail) { described_class.invite(invitation) }

    it "has the correct subject including org name" do
      expect(mail.subject).to eq("You're invited to Acme Corp on Inboxed")
    end

    it "sends to the invitee email" do
      expect(mail.to).to eq(["invitee@test.dev"])
    end

    it "includes the invitation URL in the body" do
      expect(mail.body.encoded).to include("test-invite-token")
      expect(mail.body.encoded).to include("/invitation?token=")
    end

    it "mentions the organization name in the body" do
      expect(mail.body.encoded).to include("Acme Corp")
    end
  end
end
