# frozen_string_literal: true

require "rails_helper"

# Contract tests that validate the v1 API response envelope format (ADR-032).
# These tests ensure the MCP client and any external consumers won't break
# due to accidental response shape changes.
#
# Envelope rules:
#   - Collections: { "<resource>": [...], "pagination": { "has_more", "next_cursor", "total_count" } }
#   - Single resources: { "<resource>": { ... } }
#   - Errors: RFC 7807 Problem Details with { "type", "title", "detail", "status" }

RSpec.describe "API v1 Response Contract", type: :request do
  let!(:project) do
    ProjectRecord.create!(id: SecureRandom.uuid, name: "Contract", slug: "contract-test")
  end

  let(:token) { SecureRandom.hex(32) }

  let!(:api_key) do
    ApiKeyRecord.create!(
      id: SecureRandom.uuid,
      project_id: project.id,
      token_prefix: token[0, 8],
      token_digest: BCrypt::Password.create(token),
      label: "contract"
    )
  end

  let(:headers) { {"Authorization" => "Bearer #{token}"} }

  def json
    JSON.parse(response.body)
  end

  def expect_pagination(body)
    expect(body).to have_key("pagination")
    pg = body["pagination"]
    expect(pg).to have_key("has_more")
    expect(pg).to have_key("next_cursor")
    expect(pg).to have_key("total_count")
    expect(pg["has_more"]).to be_in([true, false])
    expect(pg["total_count"]).to be_a(Integer).or(be_nil)
  end

  def expect_problem_details(body, expected_status:)
    expect(body).to have_key("type")
    expect(body).to have_key("title")
    expect(body).to have_key("detail")
    expect(body).to have_key("status")
    expect(body["status"]).to eq(expected_status)
    expect(body["type"]).to start_with("https://inboxed.notdefined.dev/docs/errors/")
  end

  # ── Inboxes ──────────────────────────────────────────────

  describe "GET /api/v1/inboxes" do
    it "returns { inboxes: [], pagination: {} }" do
      get "/api/v1/inboxes", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key("inboxes")
      expect(json["inboxes"]).to be_an(Array)
      expect_pagination(json)
    end
  end

  # ── Emails ───────────────────────────────────────────────

  describe "GET /api/v1/inboxes/:id/emails" do
    let(:inbox) do
      InboxRecord.create!(project_id: project.id, address: "contract@mail.test")
    end

    it "returns { emails: [], pagination: {} }" do
      get "/api/v1/inboxes/#{inbox.id}/emails", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key("emails")
      expect(json["emails"]).to be_an(Array)
      expect_pagination(json)
    end
  end

  describe "GET /api/v1/emails/:id" do
    let(:inbox) do
      InboxRecord.create!(project_id: project.id, address: "contract2@mail.test")
    end
    let(:email) do
      EmailRecord.create!(
        inbox: inbox,
        from_address: "sender@test.com",
        to_addresses: ["contract2@mail.test"],
        subject: "Contract test",
        body_text: "Hello",
        received_at: Time.current,
        raw_source: "raw",
        expires_at: 30.days.from_now
      )
    end

    it "returns { email: { ... } }" do
      get "/api/v1/emails/#{email.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key("email")
      expect(json["email"]).to be_a(Hash)
      expect(json["email"]["id"]).to eq(email.id)
    end
  end

  # ── Endpoints ────────────────────────────────────────────

  describe "GET /api/v1/endpoints" do
    it "returns { endpoints: [], pagination: {} }" do
      get "/api/v1/endpoints", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key("endpoints")
      expect(json["endpoints"]).to be_an(Array)
      expect_pagination(json)
    end
  end

  describe "POST /api/v1/endpoints" do
    it "returns { endpoint: { ... } }" do
      post "/api/v1/endpoints", headers: headers, params: {
        endpoint_type: "webhook", label: "Contract test"
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to have_key("endpoint")
      expect(json["endpoint"]).to be_a(Hash)
      expect(json["endpoint"]).to include("token", "url", "endpoint_type")
    end
  end

  describe "GET /api/v1/endpoints/:token" do
    let(:endpoint) do
      HttpEndpointRecord.create!(
        project_id: project.id, endpoint_type: "webhook",
        label: "show-contract", allowed_methods: %w[POST], max_body_bytes: 262_144
      )
    end

    it "returns { endpoint: { ... } }" do
      get "/api/v1/endpoints/#{endpoint.token}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key("endpoint")
      expect(json["endpoint"]["token"]).to eq(endpoint.token)
    end
  end

  # ── Requests ─────────────────────────────────────────────

  describe "GET /api/v1/endpoints/:token/requests" do
    let(:endpoint) do
      HttpEndpointRecord.create!(
        project_id: project.id, endpoint_type: "webhook",
        label: "req-contract", allowed_methods: %w[POST], max_body_bytes: 262_144
      )
    end

    it "returns { requests: [], pagination: {} }" do
      get "/api/v1/endpoints/#{endpoint.token}/requests", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key("requests")
      expect(json["requests"]).to be_an(Array)
      expect_pagination(json)
    end
  end

  describe "GET /api/v1/endpoints/:token/requests/:id" do
    let(:endpoint) do
      HttpEndpointRecord.create!(
        project_id: project.id, endpoint_type: "webhook",
        label: "req-detail", allowed_methods: %w[POST], max_body_bytes: 262_144
      )
    end
    let(:req_record) do
      HttpRequestRecord.create!(
        http_endpoint_id: endpoint.id, method: "POST",
        headers: {}, size_bytes: 0, received_at: Time.current
      )
    end

    it "returns { request: { ... } }" do
      get "/api/v1/endpoints/#{endpoint.token}/requests/#{req_record.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key("request")
      expect(json["request"]).to be_a(Hash)
      expect(json["request"]["id"]).to eq(req_record.id)
    end
  end

  # ── Webhooks ─────────────────────────────────────────────

  describe "GET /api/v1/webhooks" do
    it "returns { webhooks: [] }" do
      get "/api/v1/webhooks", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key("webhooks")
      expect(json["webhooks"]).to be_an(Array)
    end
  end

  describe "POST /api/v1/webhooks" do
    it "returns { webhook: { ... } }" do
      post "/api/v1/webhooks", headers: headers, params: {
        url: "https://example.com/hook", event_types: ["email_received"]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to have_key("webhook")
      expect(json["webhook"]).to be_a(Hash)
      expect(json["webhook"]).to include("id", "url", "event_types", "status")
    end
  end

  describe "GET /api/v1/webhooks/:id" do
    let(:webhook) do
      WebhookEndpointRecord.create!(
        id: SecureRandom.uuid, project: project,
        url: "https://example.com/hook", event_types: ["email_received"],
        secret: "whsec_#{SecureRandom.hex(32)}", status: "active"
      )
    end

    it "returns { webhook: { ... } }" do
      get "/api/v1/webhooks/#{webhook.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key("webhook")
      expect(json["webhook"]["id"]).to eq(webhook.id)
    end
  end

  describe "GET /api/v1/webhooks/:id/deliveries" do
    let(:webhook) do
      WebhookEndpointRecord.create!(
        id: SecureRandom.uuid, project: project,
        url: "https://example.com/hook", event_types: ["email_received"],
        secret: "whsec_#{SecureRandom.hex(32)}", status: "active"
      )
    end

    it "returns { deliveries: [], pagination: {} }" do
      get "/api/v1/webhooks/#{webhook.id}/deliveries", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to have_key("deliveries")
      expect(json["deliveries"]).to be_an(Array)
      expect_pagination(json)
    end
  end

  # ── Search ───────────────────────────────────────────────

  describe "GET /api/v1/search" do
    it "returns { emails: [], pagination: {} }" do
      get "/api/v1/search", headers: headers, params: {q: "test"}

      expect(response).to have_http_status(:ok)
      expect(json).to have_key("emails")
      expect(json["emails"]).to be_an(Array)
      expect_pagination(json)
    end
  end

  # ── Error responses ──────────────────────────────────────

  describe "error responses" do
    it "returns RFC 7807 Problem Details for 401" do
      get "/api/v1/status"

      expect(response).to have_http_status(:unauthorized)
      expect_problem_details(json, expected_status: 401)
    end

    it "returns RFC 7807 Problem Details for 404" do
      get "/api/v1/emails/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
      expect_problem_details(json, expected_status: 404)
    end

    it "returns RFC 7807 Problem Details for 422" do
      post "/api/v1/webhooks", headers: headers, params: {
        url: "http://example.com/hook",
        event_types: ["invalid_event"]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect_problem_details(json, expected_status: 422)
    end
  end
end
