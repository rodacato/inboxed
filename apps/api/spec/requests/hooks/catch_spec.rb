# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Hooks Catch Endpoint", type: :request do
  let!(:project) do
    ProjectRecord.create!(
      id: SecureRandom.uuid,
      name: "Test",
      slug: "test-hooks",
      default_ttl_hours: 24
    )
  end

  let!(:webhook_endpoint) do
    HttpEndpointRecord.create!(
      project_id: project.id,
      endpoint_type: "webhook",
      label: "Stripe",
      allowed_methods: %w[POST],
      max_body_bytes: 262_144
    )
  end

  describe "POST /hook/:token" do
    it "captures a JSON webhook request" do
      post "/hook/#{webhook_endpoint.token}",
        params: '{"id":"evt_1","type":"checkout.session.completed"}',
        headers: {"CONTENT_TYPE" => "application/json"}

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["ok"]).to be true
      expect(body["id"]).to be_present

      record = HttpRequestRecord.last
      expect(record.method).to eq("POST")
      expect(record.content_type).to eq("application/json")
      expect(record.body).to include("checkout.session.completed")
    end

    it "increments endpoint request_count" do
      expect {
        post "/hook/#{webhook_endpoint.token}",
          params: '{"test":true}',
          headers: {"CONTENT_TYPE" => "application/json"}
      }.to change { webhook_endpoint.reload.request_count }.by(1)
    end
  end

  describe "method restrictions" do
    it "returns 405 for disallowed method" do
      get "/hook/#{webhook_endpoint.token}"
      expect(response).to have_http_status(:method_not_allowed)
    end

    it "accepts GET when endpoint allows it" do
      endpoint = HttpEndpointRecord.create!(
        project_id: project.id,
        endpoint_type: "webhook",
        label: "get-allowed",
        allowed_methods: %w[GET POST],
        max_body_bytes: 262_144
      )

      get "/hook/#{endpoint.token}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "invalid token" do
    it "returns 404" do
      post "/hook/nonexistent_token",
        params: "test",
        headers: {"CONTENT_TYPE" => "text/plain"}

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "body size limit" do
    it "returns 413 when body exceeds max" do
      small_endpoint = HttpEndpointRecord.create!(
        project_id: project.id,
        endpoint_type: "webhook",
        label: "small",
        allowed_methods: %w[POST],
        max_body_bytes: 10
      )

      post "/hook/#{small_endpoint.token}",
        params: "x" * 100,
        headers: {"CONTENT_TYPE" => "text/plain", "CONTENT_LENGTH" => "100"}

      expect(response).to have_http_status(:payload_too_large)
    end
  end

  describe "IP allowlist" do
    it "returns 403 when IP is not in allowlist" do
      restricted = HttpEndpointRecord.create!(
        project_id: project.id,
        endpoint_type: "webhook",
        label: "restricted",
        allowed_methods: %w[POST],
        max_body_bytes: 262_144,
        allowed_ips: ["10.0.0.1"]
      )

      post "/hook/#{restricted.token}",
        params: '{"test":true}',
        headers: {"CONTENT_TYPE" => "application/json"}

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "sub-path capture" do
    it "stores the sub-path" do
      endpoint = HttpEndpointRecord.create!(
        project_id: project.id,
        endpoint_type: "webhook",
        label: "subpath",
        allowed_methods: %w[POST],
        max_body_bytes: 262_144
      )

      post "/hook/#{endpoint.token}/stripe/checkout",
        params: '{"test":true}',
        headers: {"CONTENT_TYPE" => "application/json"}

      expect(response).to have_http_status(:ok)
      expect(HttpRequestRecord.last.path).to eq("stripe/checkout")
    end
  end

  describe "form endpoint" do
    let!(:form_redirect) do
      HttpEndpointRecord.create!(
        project_id: project.id,
        endpoint_type: "form",
        label: "Contact form",
        allowed_methods: %w[POST],
        max_body_bytes: 262_144,
        response_mode: "redirect",
        response_redirect_url: "https://myapp.test/thanks"
      )
    end

    it "redirects for form endpoint with redirect mode" do
      post "/hook/#{form_redirect.token}",
        params: "name=John&email=john@test.com",
        headers: {"CONTENT_TYPE" => "application/x-www-form-urlencoded"}

      expect(response).to have_http_status(:redirect)
      expect(response.location).to eq("https://myapp.test/thanks")
    end

    it "returns HTML for form endpoint with html mode" do
      form_html = HttpEndpointRecord.create!(
        project_id: project.id,
        endpoint_type: "form",
        label: "HTML form",
        allowed_methods: %w[POST],
        max_body_bytes: 262_144,
        response_mode: "html",
        response_html: "<h1>Thanks!</h1>"
      )

      post "/hook/#{form_html.token}",
        params: "name=Test",
        headers: {"CONTENT_TYPE" => "application/x-www-form-urlencoded"}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Thanks!")
    end

    it "returns JSON for form endpoint with json mode" do
      form_json = HttpEndpointRecord.create!(
        project_id: project.id,
        endpoint_type: "form",
        label: "JSON form",
        allowed_methods: %w[POST],
        max_body_bytes: 262_144,
        response_mode: "json"
      )

      post "/hook/#{form_json.token}",
        params: "name=Test",
        headers: {"CONTENT_TYPE" => "application/x-www-form-urlencoded"}

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["ok"]).to be true
    end
  end

  describe "heartbeat endpoint" do
    let!(:heartbeat) do
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

    it "returns status in response" do
      post "/hook/#{heartbeat.token}",
        headers: {"CONTENT_TYPE" => "application/json"}

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["ok"]).to be true
      expect(body["status"]).to eq("healthy")
    end

    it "transitions heartbeat status to healthy" do
      post "/hook/#{heartbeat.token}",
        headers: {"CONTENT_TYPE" => "application/json"}

      expect(heartbeat.reload.heartbeat_status).to eq("healthy")
    end
  end
end
