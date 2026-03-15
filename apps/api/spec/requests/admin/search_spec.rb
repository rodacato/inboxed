# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Search", type: :request do
  let(:admin_token) { "test-admin-token" }
  let(:auth_headers) { {"Authorization" => "Bearer #{admin_token}"} }

  before { ENV["INBOXED_ADMIN_TOKEN"] = admin_token }
  after { ENV.delete("INBOXED_ADMIN_TOKEN") }

  let!(:project1) { ProjectRecord.create!(name: "Project One", slug: "project-one") }
  let!(:project2) { ProjectRecord.create!(name: "Project Two", slug: "project-two") }
  let!(:inbox1) { InboxRecord.create!(project: project1, address: "search1@test.dev") }
  let!(:inbox2) { InboxRecord.create!(project: project2, address: "search2@test.dev") }

  def create_email(inbox, subject:, body_text: "")
    EmailRecord.create!(
      inbox: inbox,
      from_address: "sender@example.com",
      to_addresses: [inbox.address],
      subject: subject,
      body_text: body_text,
      raw_source: "raw",
      raw_headers: {},
      received_at: Time.current,
      expires_at: 7.days.from_now,
      source_type: "relay"
    )
  end

  describe "GET /admin/search" do
    it "returns 401 without token" do
      get "/admin/search", params: {q: "test"}
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 400 without query" do
      get "/admin/search", headers: auth_headers
      expect(response).to have_http_status(:bad_request)
    end

    it "searches across all projects" do
      create_email(inbox1, subject: "Verification code 1234")
      create_email(inbox2, subject: "Verification code 5678")
      create_email(inbox1, subject: "Welcome email")

      get "/admin/search", headers: auth_headers, params: {q: "verification"}
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["emails"].size).to eq(2)
      expect(body["emails"].map { |e| e["project_name"] }).to contain_exactly("Project One", "Project Two")
    end

    it "returns empty results for no matches" do
      create_email(inbox1, subject: "Hello world")

      get "/admin/search", headers: auth_headers, params: {q: "nonexistent"}
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["emails"]).to eq([])
    end
  end
end
