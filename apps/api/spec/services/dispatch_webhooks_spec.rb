# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::DispatchWebhooks do
  subject(:service) { described_class.new }

  let!(:project) do
    ProjectRecord.create!(id: SecureRandom.uuid, name: "Test", slug: "test")
  end

  let!(:inbox) do
    InboxRecord.create!(id: SecureRandom.uuid, project: project, address: "test@example.com")
  end

  let!(:email) do
    EmailRecord.create!(
      id: SecureRandom.uuid,
      inbox: inbox,
      from_address: "sender@app.test",
      to_addresses: ["test@example.com"],
      subject: "Verify",
      body_text: "Code: 123456",
      raw_source: "From: sender@app.test\r\nSubject: Verify\r\n\r\nCode: 123456",
      raw_headers: {},
      received_at: Time.current,
      expires_at: 7.days.from_now,
      source_type: "relay"
    )
  end

  let!(:endpoint) do
    WebhookEndpointRecord.create!(
      id: SecureRandom.uuid,
      project: project,
      url: "https://example.com/webhook",
      event_types: ["email_received"],
      secret: "whsec_#{SecureRandom.hex(32)}",
      status: "active"
    )
  end

  let(:event) do
    Inboxed::Events::EmailReceived.new(
      data: {email_id: email.id, inbox_id: inbox.id}
    )
  end

  it "creates a delivery record for matching endpoints" do
    expect {
      service.call(event: event)
    }.to change(WebhookDeliveryRecord, :count).by(1)

    delivery = WebhookDeliveryRecord.last
    expect(delivery.webhook_endpoint_id).to eq(endpoint.id)
    expect(delivery.event_type).to eq("email_received")
    expect(delivery.status).to eq("pending")
  end

  it "enqueues a WebhookDeliveryJob" do
    expect {
      service.call(event: event)
    }.to have_enqueued_job(WebhookDeliveryJob)
  end

  it "skips endpoints not subscribed to the event type" do
    endpoint.update!(event_types: ["inbox_purged"])

    expect {
      service.call(event: event)
    }.not_to change(WebhookDeliveryRecord, :count)
  end

  it "skips disabled endpoints" do
    endpoint.update!(status: "disabled")

    expect {
      service.call(event: event)
    }.not_to change(WebhookDeliveryRecord, :count)
  end

  it "delivers to failing endpoints" do
    endpoint.update!(status: "failing")

    expect {
      service.call(event: event)
    }.to change(WebhookDeliveryRecord, :count).by(1)
  end

  it "builds payload with event data" do
    service.call(event: event)

    delivery = WebhookDeliveryRecord.last
    payload = delivery.payload
    expect(payload["event"]).to eq("email_received")
    expect(payload["event_id"]).to be_present
    expect(payload["data"]["email_id"]).to eq(email.id)
    expect(payload["data"]["inbox_id"]).to eq(inbox.id)
  end
end
