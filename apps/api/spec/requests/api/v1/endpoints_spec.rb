# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Endpoints", type: :request do
  let!(:project) do
    ProjectRecord.create!(id: SecureRandom.uuid, name: "Test", slug: "test-ep-api")
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
    HttpEndpointRecord.create!({
      project_id: project.id,
      endpoint_type: "webhook",
      label: "test",
      allowed_methods: %w[POST],
      max_body_bytes: 262_144
    }.merge(attrs))
  end

  describe "POST /api/v1/endpoints" do
    it "creates a webhook endpoint" do
      post "/api/v1/endpoints", headers: auth_headers, params: {
        endpoint_type: "webhook",
        label: "Stripe hooks",
        allowed_methods: ["POST"]
      }, as: :json

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      data = body["data"]
      expect(data["endpoint_type"]).to eq("webhook")
      expect(data["label"]).to eq("Stripe hooks")
      expect(data["token"]).to start_with("wh_")
      expect(data["url"]).to include("/hook/wh_")
      expect(data["request_count"]).to eq(0)
    end

    it "creates a heartbeat endpoint" do
      post "/api/v1/endpoints", headers: auth_headers, params: {
        endpoint_type: "heartbeat",
        label: "cleanup-cron",
        expected_interval_seconds: 300,
        allowed_methods: ["POST", "GET"]
      }, as: :json

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      data = body["data"]
      expect(data["endpoint_type"]).to eq("heartbeat")
      expect(data["heartbeat_status"]).to eq("pending")
      expect(data["expected_interval_seconds"]).to eq(300)
    end

    it "returns 401 without auth" do
      post "/api/v1/endpoints", params: {
        endpoint_type: "webhook", label: "test"
      }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/endpoints" do
    it "lists endpoints for the project" do
      create_endpoint(label: "Hook 1")
      create_endpoint(label: "Hook 2", endpoint_type: "form", response_mode: "json")

      get "/api/v1/endpoints", headers: auth_headers

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(2)
    end

    it "filters by type" do
      create_endpoint(endpoint_type: "webhook", label: "Webhook")
      create_endpoint(endpoint_type: "form", label: "Form", response_mode: "json")

      get "/api/v1/endpoints", headers: auth_headers, params: {type: "webhook"}

      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(1)
      expect(body["data"].first["endpoint_type"]).to eq("webhook")
    end

    it "does not show endpoints from other projects" do
      other_project = ProjectRecord.create!(id: SecureRandom.uuid, name: "Other", slug: "other-ep")
      HttpEndpointRecord.create!(
        project_id: other_project.id,
        endpoint_type: "webhook",
        label: "other",
        allowed_methods: %w[POST],
        max_body_bytes: 262_144
      )

      get "/api/v1/endpoints", headers: auth_headers

      body = JSON.parse(response.body)
      expect(body["data"].size).to eq(0)
    end
  end

  describe "GET /api/v1/endpoints/:token" do
    it "returns endpoint details" do
      endpoint = create_endpoint(label: "Stripe")

      get "/api/v1/endpoints/#{endpoint.token}", headers: auth_headers

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["data"]["token"]).to eq(endpoint.token)
      expect(body["data"]["label"]).to eq("Stripe")
    end

    it "returns 404 for other project's endpoint" do
      other_project = ProjectRecord.create!(id: SecureRandom.uuid, name: "Other", slug: "other-show")
      endpoint = HttpEndpointRecord.create!(
        project_id: other_project.id,
        endpoint_type: "webhook",
        label: "other",
        allowed_methods: %w[POST],
        max_body_bytes: 262_144
      )

      get "/api/v1/endpoints/#{endpoint.token}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/endpoints/:token" do
    it "updates the endpoint" do
      endpoint = create_endpoint(label: "Old")

      patch "/api/v1/endpoints/#{endpoint.token}", headers: auth_headers, params: {
        label: "Updated",
        description: "New description"
      }, as: :json

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["data"]["label"]).to eq("Updated")
      expect(body["data"]["description"]).to eq("New description")
    end

    it "cannot change endpoint_type" do
      endpoint = create_endpoint(endpoint_type: "webhook")

      patch "/api/v1/endpoints/#{endpoint.token}", headers: auth_headers, params: {
        endpoint_type: "form"
      }, as: :json

      expect(endpoint.reload.endpoint_type).to eq("webhook")
    end
  end

  describe "DELETE /api/v1/endpoints/:token" do
    it "deletes the endpoint and its requests" do
      endpoint = create_endpoint
      HttpRequestRecord.create!(
        http_endpoint_id: endpoint.id,
        method: "POST",
        headers: {},
        size_bytes: 0,
        received_at: Time.current
      )

      expect {
        delete "/api/v1/endpoints/#{endpoint.token}", headers: auth_headers
      }.to change(HttpEndpointRecord, :count).by(-1)
        .and change(HttpRequestRecord, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "DELETE /api/v1/endpoints/:token/purge" do
    it "deletes all requests and resets count" do
      endpoint = create_endpoint
      3.times do
        HttpRequestRecord.create!(
          http_endpoint_id: endpoint.id,
          method: "POST",
          headers: {},
          size_bytes: 0,
          received_at: Time.current
        )
      end
      HttpEndpointRecord.where(id: endpoint.id).update_all(request_count: 3)

      delete "/api/v1/endpoints/#{endpoint.token}/purge", headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["deleted_count"]).to eq(3)
      expect(endpoint.reload.request_count).to eq(0)
    end
  end
end
