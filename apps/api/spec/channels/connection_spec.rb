# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let!(:user) do
    UserRecord.create!(
      email: "ws@test.dev",
      password: "password123",
      verified_at: Time.current
    )
  end

  it "accepts connection with valid session" do
    connect "/cable", session: {user_id: user.id}
    expect(connection.current_user).to eq(user)
  end

  it "rejects connection without session" do
    expect { connect "/cable" }.to have_rejected_connection
  end

  it "rejects connection with invalid user_id in session" do
    expect { connect "/cable", session: {user_id: SecureRandom.uuid} }.to have_rejected_connection
  end
end
