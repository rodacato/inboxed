# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Endpoints::Requests", type: :request do
  let!(:project) do
    ProjectRecord.create!(id: SecureRandom.uuid, name: "Test", slug: "test-ep-req")
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

  let!(:endpoint) do
    HttpEndpointRecord.create!(
      project_id: project.id,
      endpoint_type: "webhook",
      label: "Stripe",
      allowed_methods: %w[POST],
      max_body_bytes: 262_144
    )
  end

  def create_request(attrs = {})
    HttpRequestRecord.create!({
      http_endpoint_id: endpoint.id,
      method: "POST",
      headers: {"content-type" => "application/json"},
      body: '{"event":"test"}',
      content_type: "application/json",
      ip_address: "127.0.0.1",
      size_bytes: 16,
      received_at: Time.current
    }.merge(attrs))
  end

  describe "GET /api/v1/endpoints/:token/requests" do
    it "lists captured requests" do
      create_request
      create_request(method: "POST", body: '{"event":"test2"}')

      get "/api/v1/endpoints/#{endpoint.token}/requests", headers: auth_headers

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["requests"].size).to eq(2)
      expect(body["requests"].first).to include("method", "content_type", "received_at")
    end

    it "filters by method" do
      create_request(method: "POST")
      create_request(method: "GET")

      get "/api/v1/endpoints/#{endpoint.token}/requests",
        headers: auth_headers,
        params: {method: "POST"}

      body = JSON.parse(response.body)
      expect(body["requests"].size).to eq(1)
      expect(body["requests"].first["method"]).to eq("POST")
    end
  end

  describe "GET /api/v1/endpoints/:token/requests/:id" do
    it "returns request detail with full body and headers" do
      req = create_request

      get "/api/v1/endpoints/#{endpoint.token}/requests/#{req.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      data = body["request"]
      expect(data["id"]).to eq(req.id)
      expect(data["body"]).to eq('{"event":"test"}')
      expect(data["headers"]).to include("content-type" => "application/json")
    end
  end

  describe "DELETE /api/v1/endpoints/:token/requests/:id" do
    it "deletes a single request and decrements count" do
      req = create_request
      HttpEndpointRecord.where(id: endpoint.id).update_all(request_count: 1)

      expect {
        delete "/api/v1/endpoints/#{endpoint.token}/requests/#{req.id}", headers: auth_headers
      }.to change(HttpRequestRecord, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(endpoint.reload.request_count).to eq(0)
    end
  end

  describe "POST /api/v1/endpoints/:token/requests/wait" do
    it "returns a recent request" do
      req = create_request(received_at: 1.second.from_now)

      post "/api/v1/endpoints/#{endpoint.token}/requests/wait",
        headers: auth_headers,
        params: {timeout: 2},
        as: :json

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["request"]["id"]).to eq(req.id)
    end

    it "returns 408 on timeout" do
      post "/api/v1/endpoints/#{endpoint.token}/requests/wait",
        headers: auth_headers,
        params: {timeout: 1},
        as: :json

      expect(response).to have_http_status(:request_timeout)
    end
  end
end
