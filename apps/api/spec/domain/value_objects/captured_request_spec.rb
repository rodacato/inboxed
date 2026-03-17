# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::ValueObjects::CapturedRequest do
  it "builds from hash data" do
    req = described_class.new(
      method: "POST",
      path: "/stripe/checkout",
      query_string: "version=2",
      headers: {"content-type" => "application/json"},
      body: '{"id":"evt_1"}',
      content_type: "application/json",
      ip_address: "54.187.174.169",
      size_bytes: 14
    )

    expect(req.attributes[:method]).to eq("POST")
    expect(req.path).to eq("/stripe/checkout")
    expect(req.headers).to include("content-type" => "application/json")
    expect(req.size_bytes).to eq(14)
  end

  it "defaults optional fields to nil" do
    req = described_class.new(method: "GET")

    expect(req.path).to be_nil
    expect(req.body).to be_nil
    expect(req.size_bytes).to eq(0)
  end
end
