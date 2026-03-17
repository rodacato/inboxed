# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::CheckHeartbeats do
  subject(:service) { described_class.new }

  let!(:project) do
    ProjectRecord.create!(id: SecureRandom.uuid, name: "Test", slug: "test-heartbeat")
  end

  def create_heartbeat(status:, last_ping_at:, interval: 300)
    HttpEndpointRecord.create!(
      project_id: project.id,
      endpoint_type: "heartbeat",
      label: "cron-#{SecureRandom.hex(4)}",
      allowed_methods: %w[POST],
      max_body_bytes: 262_144,
      expected_interval_seconds: interval,
      heartbeat_status: status,
      last_ping_at: last_ping_at,
      status_changed_at: last_ping_at
    )
  end

  it "does nothing when no active heartbeats exist" do
    expect { service.call }.not_to raise_error
  end

  it "does not check pending heartbeats (no pings yet)" do
    endpoint = HttpEndpointRecord.create!(
      project_id: project.id,
      endpoint_type: "heartbeat",
      label: "pending-cron",
      allowed_methods: %w[POST],
      max_body_bytes: 262_144,
      expected_interval_seconds: 300,
      heartbeat_status: "pending"
    )

    service.call

    expect(endpoint.reload.heartbeat_status).to eq("pending")
  end

  it "keeps healthy status when ping is within interval" do
    endpoint = create_heartbeat(status: "healthy", last_ping_at: 2.minutes.ago)

    service.call

    expect(endpoint.reload.heartbeat_status).to eq("healthy")
  end

  it "transitions healthy to late when ping missed 1x interval" do
    endpoint = create_heartbeat(status: "healthy", last_ping_at: 6.minutes.ago)

    service.call

    expect(endpoint.reload.heartbeat_status).to eq("late")
  end

  it "transitions healthy to down when ping missed 2x interval" do
    endpoint = create_heartbeat(status: "healthy", last_ping_at: 11.minutes.ago)

    service.call

    expect(endpoint.reload.heartbeat_status).to eq("down")
  end

  it "transitions late to down when ping missed 2x interval" do
    endpoint = create_heartbeat(status: "late", last_ping_at: 11.minutes.ago)

    service.call

    expect(endpoint.reload.heartbeat_status).to eq("down")
  end

  it "publishes HeartbeatStatusChanged event on transition" do
    create_heartbeat(status: "healthy", last_ping_at: 6.minutes.ago)

    service.call

    events = EventRecord.where(event_type: "Inboxed::Events::HeartbeatStatusChanged")
    expect(events.count).to eq(1)
  end

  it "fires webhook notification when transitioning to down" do
    webhook = WebhookEndpointRecord.create!(
      id: SecureRandom.uuid,
      project_id: project.id,
      url: "https://example.com/alert",
      event_types: ["heartbeat_down"],
      secret: "whsec_#{SecureRandom.hex(32)}",
      status: "active"
    )

    create_heartbeat(status: "late", last_ping_at: 11.minutes.ago)

    expect {
      service.call
    }.to change(WebhookDeliveryRecord, :count).by(1)

    delivery = WebhookDeliveryRecord.last
    expect(delivery.event_type).to eq("heartbeat_down")
    expect(delivery.webhook_endpoint_id).to eq(webhook.id)
  end

  it "fires recovery webhook when transitioning from down to healthy via CheckHeartbeats" do
    webhook = WebhookEndpointRecord.create!(
      id: SecureRandom.uuid,
      project_id: project.id,
      url: "https://example.com/alert",
      event_types: ["heartbeat_recovered"],
      secret: "whsec_#{SecureRandom.hex(32)}",
      status: "active"
    )

    # Endpoint was down, but now last_ping_at is recent (simulating a ping just arrived)
    endpoint = create_heartbeat(status: "down", last_ping_at: 1.minute.ago)

    expect {
      service.call
    }.to change(WebhookDeliveryRecord, :count).by(1)

    delivery = WebhookDeliveryRecord.last
    expect(delivery.event_type).to eq("heartbeat_recovered")
    expect(endpoint.reload.heartbeat_status).to eq("healthy")
  end
end
