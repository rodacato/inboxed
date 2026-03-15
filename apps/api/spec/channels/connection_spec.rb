# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:admin_token) { "test-admin-token" }

  before { ENV["INBOXED_ADMIN_TOKEN"] = admin_token }
  after { ENV.delete("INBOXED_ADMIN_TOKEN") }

  it "accepts connection with valid admin token" do
    connect "/cable?token=#{admin_token}"
    expect(connection.admin_authenticated).to be true
  end

  it "rejects connection without token" do
    expect { connect "/cable" }.to have_rejected_connection
  end

  it "rejects connection with invalid token" do
    expect { connect "/cable?token=wrong" }.to have_rejected_connection
  end

  it "rejects connection when admin token is not configured" do
    ENV.delete("INBOXED_ADMIN_TOKEN")
    expect { connect "/cable?token=anything" }.to have_rejected_connection
  end
end
