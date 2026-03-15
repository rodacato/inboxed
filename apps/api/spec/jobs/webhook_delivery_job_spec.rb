# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

RSpec.describe WebhookDeliveryJob do
  before { ActiveJob::Base.queue_adapter = :test }
  let!(:project) do
    ProjectRecord.create!(id: SecureRandom.uuid, name: "Test", slug: "test")
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

  let!(:delivery) do
    WebhookDeliveryRecord.create!(
      id: SecureRandom.uuid,
      webhook_endpoint: endpoint,
      event_type: "email_received",
      event_id: SecureRandom.uuid,
      payload: {event: "email_received", data: {email_id: SecureRandom.uuid}},
      status: "pending",
      attempt_count: 0
    )
  end

  def stub_webhook_request(status: 200, body: "OK")
    stub_request(:post, endpoint.url)
      .to_return(status: status, body: body)
  end

  it "marks delivery as delivered on 2xx response" do
    stub_webhook_request(status: 200)

    described_class.perform_now(delivery.id)

    delivery.reload
    expect(delivery.status).to eq("delivered")
    expect(delivery.http_status).to eq(200)
    expect(delivery.attempt_count).to eq(1)
  end

  it "resets endpoint failure count on success" do
    endpoint.update!(failure_count: 3, status: "failing")
    stub_webhook_request(status: 200)

    described_class.perform_now(delivery.id)

    endpoint.reload
    expect(endpoint.failure_count).to eq(0)
    expect(endpoint.status).to eq("active")
  end

  it "marks attempt failed on non-2xx response" do
    stub_webhook_request(status: 500, body: "Internal Server Error")

    described_class.perform_now(delivery.id)

    delivery.reload
    expect(delivery.http_status).to eq(500)
    expect(delivery.attempt_count).to eq(1)
    expect(delivery.next_retry_at).to be_present
  end

  it "increments endpoint failure count on failure" do
    stub_webhook_request(status: 500)

    described_class.perform_now(delivery.id)

    endpoint.reload
    expect(endpoint.failure_count).to eq(1)
  end

  it "sets endpoint to failing after 3 consecutive failures" do
    endpoint.update!(failure_count: 2)
    stub_webhook_request(status: 500)

    described_class.perform_now(delivery.id)

    endpoint.reload
    expect(endpoint.status).to eq("failing")
  end

  it "disables endpoint after 10 consecutive failures" do
    endpoint.update!(failure_count: 9, status: "failing")
    stub_webhook_request(status: 500)

    described_class.perform_now(delivery.id)

    endpoint.reload
    expect(endpoint.status).to eq("disabled")
  end

  it "skips delivery for disabled endpoints" do
    endpoint.update!(status: "disabled")

    described_class.perform_now(delivery.id)

    delivery.reload
    expect(delivery.status).to eq("pending")
    expect(delivery.attempt_count).to eq(0)
  end

  it "schedules retry on failure" do
    stub_webhook_request(status: 500)

    expect {
      described_class.perform_now(delivery.id)
    }.to have_enqueued_job(described_class).with(delivery.id)
  end

  it "marks as permanently failed after max attempts" do
    delivery.update!(attempt_count: 5)
    stub_webhook_request(status: 500)

    described_class.perform_now(delivery.id)

    delivery.reload
    expect(delivery.status).to eq("failed")
    expect(delivery.next_retry_at).to be_nil
  end

  it "sends correct headers" do
    request_stub = stub_webhook_request(status: 200)

    described_class.perform_now(delivery.id)

    expect(request_stub).to have_been_requested
    expect(WebMock).to have_requested(:post, endpoint.url)
      .with { |req|
        req.headers["X-Inboxed-Event"] == "email_received" &&
          req.headers["X-Inboxed-Signature"]&.start_with?("sha256=") &&
          req.headers["X-Inboxed-Delivery"] == delivery.id &&
          req.headers["User-Agent"] == "Inboxed-Webhook/1.0"
      }
  end

  it "handles connection errors gracefully" do
    stub_request(:post, endpoint.url).to_raise(Errno::ECONNREFUSED)

    described_class.perform_now(delivery.id)

    delivery.reload
    expect(delivery.http_status).to be_nil
    expect(delivery.attempt_count).to eq(1)
    expect(delivery.response_body).to include("Connection refused")
  end
end
