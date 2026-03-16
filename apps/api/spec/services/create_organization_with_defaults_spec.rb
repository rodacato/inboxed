# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::CreateOrganizationWithDefaults do
  subject(:service) { described_class.new }

  let(:user) { UserRecord.create!(email: "orgcreator@test.dev", password: "password123") }

  after { ENV.delete("TRIAL_DURATION_DAYS") }

  it "creates org with slug, membership, project, and API key" do
    org = service.call(name: "New Org", user: user)

    expect(org).to be_persisted
    expect(org.slug).to be_present
    expect(MembershipRecord.where(user: user, organization: org).count).to eq(1)

    project = ProjectRecord.find_by(organization: org)
    expect(project).to be_present
    expect(ApiKeyRecord.where(project: project).count).to eq(1)
  end

  it "respects trial_days parameter" do
    org = service.call(name: "Trial Org", user: user, trial_days: 14)

    expect(org.trial?).to be true
    expect(org.days_remaining).to be_between(13, 14)
  end

  it "creates permanent org when trial_days=0" do
    org = service.call(name: "Permanent Org", user: user, trial_days: 0)

    expect(org.permanent?).to be true
    expect(org.trial_ends_at).to be_nil
  end
end
