# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::InviteUser do
  let(:event_store) { double("EventStore", publish: nil) }
  subject(:service) { described_class.new(event_store: event_store) }

  let(:org) { OrganizationRecord.create!(name: "Invite Org", slug: "invite-org-#{SecureRandom.hex(4)}") }
  let(:inviter) { UserRecord.create!(email: "inviter@test.dev", password: "password123") }

  after { ENV.delete("OUTBOUND_SMTP_HOST") }

  it "creates an invitation with correct fields" do
    invitation = service.call(
      organization: org,
      email: "  NewUser@Test.Dev  ",
      role: "member",
      invited_by: inviter
    )

    expect(invitation).to be_persisted
    expect(invitation.email).to eq("newuser@test.dev")
    expect(invitation.role).to eq("member")
    expect(invitation.organization).to eq(org)
    expect(invitation.invited_by).to eq(inviter)
    expect(invitation.token).to be_present
    expect(invitation.expires_at).to be > Time.current
  end

  it "publishes UserInvited event" do
    service.call(
      organization: org,
      email: "eventuser@test.dev",
      role: "org_admin",
      invited_by: inviter
    )

    expect(event_store).to have_received(:publish).with(
      hash_including(
        stream: "organization-#{org.id}",
        events: [an_instance_of(Inboxed::Events::UserInvited)]
      )
    )
  end
end
