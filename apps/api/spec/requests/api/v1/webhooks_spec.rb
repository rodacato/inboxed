# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Webhooks", type: :request do
  let!(:project) do
    ProjectRecord.create!(id: SecureRandom.uuid, name: "Test", slug: "test")
  end

  let(:token) { SecureRandom.hex(32) }

  let!(:api_key) do
    ApiKeyRecord.create!(
      id: SecureRandom.uuid,
      project_id: project.id,
      token_prefix: token[0, 8],
      token_digest: BCrypt::Password.create(token),
      label: "test"
    )
  end

  let(:auth_headers) { {"Authorization" => "Bearer #{token}"} }

  def create_endpoint(attrs = {})
    WebhookEndpointRecord.create!({
      id: SecureRandom.uuid,
      project: project,
      url: "https://example.com/webhook",
      event_types: ["email_received"],
      secret: "whsec_#{SecureRandom.hex(32)}",
      status: "active"
    }.merge(attrs))
  end

  describe "POST /api/v1/webhooks" do
    it "creates a webhook endpoint" do
      post "/api/v1/webhooks", headers: auth_headers, params: {
        url: "https://example.com/hook",
        event_types: ["email_received"],
        description: "CI pipeline"
      }, as: :json

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      data = body["data"]
      expect(data["url"]).to eq("https://example.com/hook")
      expect(data["event_types"]).to eq(["email_received"])
      expect(data["status"]).to eq("active")
      expect(data["secret"]).to start_with("whsec_")
      expect(data["description"]).to eq("CI pipeline")
    end

    it "rejects HTTP URLs (non-localhost)" do
      post "/api/v1/webhooks", headers: auth_headers, params: {
        url: "http://example.com/hook",
        event_types: ["email_received"]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "allows HTTP for localhost" do
      post "/api/v1/webhooks", headers: auth_headers, params: {
        url: "http://localhost:4000/hook",
        event_types: ["email_received"]
      }, as: :json

      expect(response).to have_http_status(:created)
    end

    it "rejects invalid event types" do
      post "/api/v1/webhooks", headers: auth_headers, params: {
        url: "https://example.com/hook",
        event_types: ["invalid_event"]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 401 without auth" do
      post "/api/v1/webhooks", params: {
        url: "https://example.com/hook",
        event_types: ["email_received"]
      }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/webhooks" do
    it "lists endpoints for the project" do
      create_endpoint(description: "Hook 1")
      create_endpoint(url: "https://other.com/hook", description: "Hook 2")

      get "/api/v1/webhooks", headers: auth_headers

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(2)
      expect(body["data"].first).not_to have_key("secret")
    end

    it "does not show endpoints from other projects" do
      other_project = ProjectRecord.create!(id: SecureRandom.uuid, name: "Other", slug: "other")
      WebhookEndpointRecord.create!(
        id: SecureRandom.uuid,
        project: other_project,
        url: "https://other.com/hook",
        event_types: ["email_received"],
        secret: "whsec_#{SecureRandom.hex(32)}"
      )

      get "/api/v1/webhooks", headers: auth_headers

      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(0)
    end
  end

  describe "GET /api/v1/webhooks/:id" do
    it "returns endpoint with delivery stats" do
      endpoint = create_endpoint

      get "/api/v1/webhooks/#{endpoint.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["data"]["id"]).to eq(endpoint.id)
      expect(body["data"]["stats"]).to include(
        "total_deliveries" => 0,
        "successful" => 0,
        "failed" => 0,
        "pending" => 0
      )
    end

    it "returns 404 for other project's endpoint" do
      other_project = ProjectRecord.create!(id: SecureRandom.uuid, name: "Other", slug: "other")
      endpoint = WebhookEndpointRecord.create!(
        id: SecureRandom.uuid,
        project: other_project,
        url: "https://example.com/hook",
        event_types: ["email_received"],
        secret: "whsec_#{SecureRandom.hex(32)}"
      )

      get "/api/v1/webhooks/#{endpoint.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/webhooks/:id" do
    it "updates the endpoint" do
      endpoint = create_endpoint

      patch "/api/v1/webhooks/#{endpoint.id}", headers: auth_headers, params: {
        description: "Updated",
        event_types: ["email_received", "email_deleted"]
      }, as: :json

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["data"]["description"]).to eq("Updated")
      expect(body["data"]["event_types"]).to eq(["email_received", "email_deleted"])
    end

    it "re-enables a disabled endpoint" do
      endpoint = create_endpoint(status: "disabled", failure_count: 10)

      patch "/api/v1/webhooks/#{endpoint.id}", headers: auth_headers, params: {
        status: "active"
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]["status"]).to eq("active")
    end
  end

  describe "DELETE /api/v1/webhooks/:id" do
    it "deletes the endpoint and its deliveries" do
      endpoint = create_endpoint
      WebhookDeliveryRecord.create!(
        id: SecureRandom.uuid,
        webhook_endpoint: endpoint,
        event_type: "email_received",
        event_id: SecureRandom.uuid,
        payload: {},
        status: "delivered"
      )

      expect {
        delete "/api/v1/webhooks/#{endpoint.id}", headers: auth_headers
      }.to change(WebhookEndpointRecord, :count).by(-1)
        .and change(WebhookDeliveryRecord, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/v1/webhooks/:id/deliveries" do
    it "lists deliveries for the endpoint" do
      endpoint = create_endpoint
      3.times do |i|
        WebhookDeliveryRecord.create!(
          id: SecureRandom.uuid,
          webhook_endpoint: endpoint,
          event_type: "email_received",
          event_id: "evt_#{i}",
          payload: {event: "email_received"},
          status: "delivered",
          http_status: 200,
          attempt_count: 1,
          last_attempted_at: Time.current
        )
      end

      get "/api/v1/webhooks/#{endpoint.id}/deliveries", headers: auth_headers

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(3)
      expect(body["data"].first).to include("event_type", "status", "http_status")
    end
  end
end
