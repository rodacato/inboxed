# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::CaptureHttpRequest do
  subject(:service) { described_class.new }

  let!(:project) do
    ProjectRecord.create!(
      id: SecureRandom.uuid,
      name: "Test Project",
      slug: "test-capture",
      default_ttl_hours: 24
    )
  end

  let!(:endpoint) do
    HttpEndpointRecord.create!(
      project_id: project.id,
      endpoint_type: "webhook",
      label: "Stripe hooks",
      allowed_methods: %w[POST],
      max_body_bytes: 262_144
    )
  end

  let(:request_data) do
    {
      method: "POST",
      path: "/checkout.completed",
      query_string: "foo=bar",
      headers: {"content-type" => "application/json", "stripe-signature" => "t=123,v1=abc"},
      body: '{"id":"evt_1","type":"checkout.session.completed"}',
      content_type: "application/json",
      ip_address: "54.187.174.169",
      size_bytes: 50
    }
  end

  it "creates an HttpRequestRecord" do
    expect {
      service.call(endpoint: endpoint, request_data: request_data)
    }.to change(HttpRequestRecord, :count).by(1)

    record = HttpRequestRecord.last
    expect(record.method).to eq("POST")
    expect(record.path).to eq("/checkout.completed")
    expect(record.query_string).to eq("foo=bar")
    expect(record.headers).to include("content-type" => "application/json")
    expect(record.body).to include("checkout.session.completed")
    expect(record.content_type).to eq("application/json")
    expect(record.ip_address).to eq("54.187.174.169")
    expect(record.size_bytes).to eq(50)
    expect(record.received_at).to be_present
  end

  it "sets expires_at based on project TTL" do
    service.call(endpoint: endpoint, request_data: request_data)

    record = HttpRequestRecord.last
    expect(record.expires_at).to be_within(1.minute).of(24.hours.from_now)
  end

  it "increments the endpoint request_count" do
    expect {
      service.call(endpoint: endpoint, request_data: request_data)
    }.to change { endpoint.reload.request_count }.by(1)
  end

  it "returns request_id in the result" do
    result = service.call(endpoint: endpoint, request_data: request_data)

    expect(result[:request_id]).to eq(HttpRequestRecord.last.id)
  end

  it "publishes an HttpRequestCaptured event" do
    service.call(endpoint: endpoint, request_data: request_data)

    events = EventRecord.where(event_type: "Inboxed::Events::HttpRequestCaptured")
    expect(events.count).to eq(1)
  end

  context "with a heartbeat endpoint" do
    let!(:heartbeat_endpoint) do
      HttpEndpointRecord.create!(
        project_id: project.id,
        endpoint_type: "heartbeat",
        label: "cleanup-cron",
        allowed_methods: %w[POST GET],
        max_body_bytes: 262_144,
        expected_interval_seconds: 300,
        heartbeat_status: "pending"
      )
    end

    it "transitions status from pending to healthy on first ping" do
      service.call(endpoint: heartbeat_endpoint, request_data: request_data)

      heartbeat_endpoint.reload
      expect(heartbeat_endpoint.heartbeat_status).to eq("healthy")
      expect(heartbeat_endpoint.last_ping_at).to be_present
    end

    it "transitions status from down to healthy and publishes recovery event" do
      heartbeat_endpoint.update!(heartbeat_status: "down", last_ping_at: 1.hour.ago, status_changed_at: 1.hour.ago)

      service.call(endpoint: heartbeat_endpoint, request_data: request_data)

      heartbeat_endpoint.reload
      expect(heartbeat_endpoint.heartbeat_status).to eq("healthy")

      events = EventRecord.where(event_type: "Inboxed::Events::HeartbeatStatusChanged")
      expect(events.count).to eq(1)
    end

    it "returns heartbeat_status in the result" do
      result = service.call(endpoint: heartbeat_endpoint, request_data: request_data)
      expect(result[:heartbeat_status]).to eq("healthy")
    end
  end

  context "with nil heartbeat_status for non-heartbeat endpoint" do
    it "returns nil heartbeat_status" do
      result = service.call(endpoint: endpoint, request_data: request_data)
      expect(result[:heartbeat_status]).to be_nil
    end
  end
end
