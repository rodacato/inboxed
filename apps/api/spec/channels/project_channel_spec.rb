# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectChannel, type: :channel do
  let(:project_id) { SecureRandom.uuid }
  let!(:user) do
    UserRecord.create!(
      email: "channel@test.dev",
      password: "password123",
      verified_at: Time.current
    )
  end

  before do
    stub_connection current_user: user
  end

  it "subscribes to the project stream" do
    subscribe(project_id: project_id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("project_#{project_id}")
  end
end
