# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::CreateOrganizationWithDefaults do
  subject(:service) { described_class.new }

  let(:user) { UserRecord.create!(email: "orgcreator@test.dev", password: "password123") }

  after { ENV.delete("TRIAL_DURATION_DAYS") }

  it "creates org with slug, membership, project, and API key" do
    result = service.call(name: "New Org", user: user)

    expect(result.organization).to be_persisted
    expect(result.organization.slug).to be_present
    expect(result.project).to be_persisted
    expect(result.api_key[:token]).to be_present
    expect(MembershipRecord.where(user: user, organization: result.organization).count).to eq(1)

    expect(ApiKeyRecord.where(project: result.project).count).to eq(1)
  end

  it "respects trial_days parameter" do
    result = service.call(name: "Trial Org", user: user, trial_days: 14)

    expect(result.organization.trial?).to be true
    expect(result.organization.days_remaining).to be_between(13, 14)
  end

  it "creates permanent org when trial_days=0" do
    result = service.call(name: "Permanent Org", user: user, trial_days: 0)

    expect(result.organization.permanent?).to be true
    expect(result.organization.trial_ends_at).to be_nil
  end
end
