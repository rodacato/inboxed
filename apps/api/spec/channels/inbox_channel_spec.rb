# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboxChannel, type: :channel do
  let(:inbox_id) { SecureRandom.uuid }
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

  it "subscribes to the inbox stream" do
    subscribe(inbox_id: inbox_id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("inbox_#{inbox_id}")
  end
end
