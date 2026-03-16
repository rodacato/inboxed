# frozen_string_literal: true

require "rails_helper"

RSpec.describe MaintenanceCleanupJob do
  describe "session cleanup" do
    let!(:old_session) do
      SessionRecord.create!(
        session_id: SecureRandom.hex(16),
        data: "old-session-data",
        created_at: 8.days.ago,
        updated_at: 8.days.ago
      )
    end

    let!(:recent_session) do
      SessionRecord.create!(
        session_id: SecureRandom.hex(16),
        data: "recent-session-data",
        created_at: 1.day.ago,
        updated_at: 1.day.ago
      )
    end

    it "deletes sessions older than 7 days" do
      expect { described_class.perform_now }
        .to change(SessionRecord, :count).by(-1)

      expect(SessionRecord.exists?(old_session.id)).to be false
      expect(SessionRecord.exists?(recent_session.id)).to be true
    end
  end

  describe "expired invitation cleanup" do
    let!(:org) do
      OrganizationRecord.create!(
        name: "Test Org",
        slug: "test-org-#{SecureRandom.hex(4)}",
        trial_ends_at: nil
      )
    end

    let!(:user) do
      u = UserRecord.create!(email: "admin@test.dev", password: "password123", verified_at: Time.current)
      MembershipRecord.create!(user: u, organization: org, role: "org_admin")
      u
    end

    let!(:expired_invitation) do
      InvitationRecord.create!(
        organization: org,
        email: "expired@test.dev",
        role: "member",
        token: SecureRandom.urlsafe_base64(32),
        invited_by: user,
        expires_at: 1.day.ago
      )
    end

    let!(:active_invitation) do
      InvitationRecord.create!(
        organization: org,
        email: "active@test.dev",
        role: "member",
        token: SecureRandom.urlsafe_base64(32),
        invited_by: user,
        expires_at: 7.days.from_now
      )
    end

    it "deletes expired unaccepted invitations" do
      expect { described_class.perform_now }
        .to change(InvitationRecord, :count).by(-1)

      expect(InvitationRecord.exists?(expired_invitation.id)).to be false
      expect(InvitationRecord.exists?(active_invitation.id)).to be true
    end
  end

  describe "unverified user cleanup" do
    context "when SMTP is configured" do
      before { ENV["OUTBOUND_SMTP_HOST"] = "smtp.test.dev" }
      after { ENV.delete("OUTBOUND_SMTP_HOST") }

      let!(:old_unverified_user) do
        UserRecord.create!(
          email: "old-unverified@test.dev",
          password: "password123",
          verified_at: nil,
          created_at: 3.days.ago
        )
      end

      let!(:recent_unverified_user) do
        UserRecord.create!(
          email: "recent-unverified@test.dev",
          password: "password123",
          verified_at: nil,
          created_at: 1.hour.ago
        )
      end

      it "deletes unverified users older than 48 hours" do
        expect { described_class.perform_now }
          .to change(UserRecord, :count).by(-1)

        expect(UserRecord.exists?(old_unverified_user.id)).to be false
        expect(UserRecord.exists?(recent_unverified_user.id)).to be true
      end
    end

    context "when SMTP is not configured" do
      before { ENV.delete("OUTBOUND_SMTP_HOST") }

      let!(:old_unverified_user) do
        UserRecord.create!(
          email: "old-unverified@test.dev",
          password: "password123",
          verified_at: nil,
          created_at: 3.days.ago
        )
      end

      it "does not delete unverified users" do
        expect { described_class.perform_now }
          .not_to change(UserRecord, :count)
      end
    end
  end
end
