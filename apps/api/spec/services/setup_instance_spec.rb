# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::SetupInstance do
  let(:event_store) { double("EventStore", publish: nil) }
  subject(:service) { described_class.new(event_store: event_store) }

  it "creates a user, org, membership, project, and API key" do
    result = service.call(email: "admin@test.dev", password: "password123", org_name: "My Company")

    expect(result.user).to be_persisted
    expect(result.organization).to be_persisted
    expect(MembershipRecord.where(user: result.user, organization: result.organization).count).to eq(1)
    expect(ProjectRecord.where(organization: result.organization).count).to eq(1)

    project = ProjectRecord.find_by(organization: result.organization)
    expect(ApiKeyRecord.where(project: project).count).to eq(1)
  end

  it "makes the user a site_admin and verified" do
    result = service.call(email: "admin2@test.dev", password: "password123", org_name: "Admin Corp")

    expect(result.user.site_admin?).to be true
    expect(result.user.verified?).to be true
  end

  it "creates a permanent org (trial_ends_at nil)" do
    result = service.call(email: "admin3@test.dev", password: "password123", org_name: "Permanent Corp")

    expect(result.organization.permanent?).to be true
    expect(result.organization.trial_ends_at).to be_nil
  end

  it "sets setup_completed_at setting" do
    service.call(email: "admin4@test.dev", password: "password123", org_name: "Setup Corp")

    expect(Inboxed::Settings.setup_completed?).to be true
  end

  it "publishes UserRegistered event" do
    service.call(email: "admin5@test.dev", password: "password123", org_name: "Event Corp")

    expect(event_store).to have_received(:publish).with(
      hash_including(
        stream: a_string_matching(/^user-/),
        events: [an_instance_of(Inboxed::Events::UserRegistered)]
      )
    )
  end
end
