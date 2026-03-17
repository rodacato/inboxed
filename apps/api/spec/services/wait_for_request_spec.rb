# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::WaitForRequest do
  subject(:service) { described_class.new }

  let!(:project) do
    ProjectRecord.create!(id: SecureRandom.uuid, name: "Test", slug: "test-wait")
  end

  let!(:endpoint) do
    HttpEndpointRecord.create!(
      project_id: project.id,
      endpoint_type: "webhook",
      label: "Stripe",
      allowed_methods: %w[POST],
      max_body_bytes: 262_144
    )
  end

  it "returns a request that arrives after the call starts" do
    # Create a request slightly in the future to ensure it's after cutoff
    request = HttpRequestRecord.create!(
      http_endpoint_id: endpoint.id,
      method: "POST",
      headers: {},
      body: '{"test": true}',
      content_type: "application/json",
      size_bytes: 14,
      received_at: 1.second.from_now
    )

    result = service.call(
      token: endpoint.token,
      project_id: project.id,
      timeout_seconds: 2
    )

    expect(result).to be_present
    expect(result.id).to eq(request.id)
  end

  it "returns nil on timeout when no request arrives" do
    result = service.call(
      token: endpoint.token,
      project_id: project.id,
      timeout_seconds: 1
    )

    expect(result).to be_nil
  end

  it "filters by HTTP method" do
    HttpRequestRecord.create!(
      http_endpoint_id: endpoint.id,
      method: "GET",
      headers: {},
      size_bytes: 0,
      received_at: Time.current
    )

    result = service.call(
      token: endpoint.token,
      project_id: project.id,
      method: "POST",
      timeout_seconds: 1
    )

    expect(result).to be_nil
  end

  it "caps timeout at MAX_TIMEOUT" do
    start = Time.current

    service.call(
      token: endpoint.token,
      project_id: project.id,
      timeout_seconds: 999
    )

    elapsed = Time.current - start
    expect(elapsed).to be < 35 # MAX_TIMEOUT (30) + margin
  end

  it "raises RecordNotFound for invalid token" do
    expect {
      service.call(token: "invalid", project_id: project.id, timeout_seconds: 1)
    }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
