# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboxChannel, type: :channel do
  let(:inbox_id) { SecureRandom.uuid }

  before do
    stub_connection admin_authenticated: true
  end

  it "subscribes to the inbox stream" do
    subscribe(inbox_id: inbox_id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("inbox_#{inbox_id}")
  end
end
