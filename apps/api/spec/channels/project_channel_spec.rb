# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectChannel, type: :channel do
  let(:project_id) { SecureRandom.uuid }

  before do
    stub_connection admin_authenticated: true
  end

  it "subscribes to the project stream" do
    subscribe(project_id: project_id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("project_#{project_id}")
  end
end
