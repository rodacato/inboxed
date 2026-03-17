# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Services::CreateHttpEndpoint do
  subject(:service) { described_class.new }

  let!(:project) do
    ProjectRecord.create!(id: SecureRandom.uuid, name: "Test", slug: "test-create-ep")
  end

  describe "webhook endpoint" do
    it "creates a webhook endpoint with token prefix wh_" do
      result = service.call(
        project_id: project.id,
        params: {endpoint_type: "webhook", label: "Stripe hooks"}
      )

      expect(result).to be_a(HttpEndpointRecord)
      expect(result.endpoint_type).to eq("webhook")
      expect(result.label).to eq("Stripe hooks")
      expect(result.token).to start_with("wh_")
      expect(result.heartbeat_status).to be_nil
    end

    it "defaults allowed_methods to all HTTP methods" do
      result = service.call(
        project_id: project.id,
        params: {endpoint_type: "webhook", label: "test"}
      )

      expect(result.allowed_methods).to eq(HttpEndpointRecord::VALID_HTTP_METHODS)
    end
  end

  describe "form endpoint" do
    it "creates a form endpoint with token prefix fm_" do
      result = service.call(
        project_id: project.id,
        params: {
          endpoint_type: "form",
          label: "Contact form",
          response_mode: "redirect",
          response_redirect_url: "https://myapp.test/thanks"
        }
      )

      expect(result.endpoint_type).to eq("form")
      expect(result.token).to start_with("fm_")
      expect(result.response_mode).to eq("redirect")
      expect(result.response_redirect_url).to eq("https://myapp.test/thanks")
    end
  end

  describe "heartbeat endpoint" do
    it "creates a heartbeat endpoint with pending status" do
      result = service.call(
        project_id: project.id,
        params: {
          endpoint_type: "heartbeat",
          label: "cleanup-cron",
          expected_interval_seconds: 300
        }
      )

      expect(result.endpoint_type).to eq("heartbeat")
      expect(result.token).to start_with("hb_")
      expect(result.heartbeat_status).to eq("pending")
      expect(result.expected_interval_seconds).to eq(300)
    end
  end

  it "publishes an HttpEndpointCreated event" do
    service.call(project_id: project.id, params: {endpoint_type: "webhook", label: "test"})

    events = EventRecord.where(event_type: "Inboxed::Events::HttpEndpointCreated")
    expect(events.count).to eq(1)
  end

  it "defaults to webhook when no type specified" do
    result = service.call(project_id: project.id, params: {label: "test"})
    expect(result.endpoint_type).to eq("webhook")
  end
end
