# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Inboxes", type: :request do
  let(:admin_token) { "test-admin-token" }
  let(:auth_headers) { {"Authorization" => "Bearer #{admin_token}"} }

  before { ENV["INBOXED_ADMIN_TOKEN"] = admin_token }
  after { ENV.delete("INBOXED_ADMIN_TOKEN") }

  let!(:project) { ProjectRecord.create!(name: "Test Project", slug: "test-project") }

  describe "GET /admin/projects/:project_id/inboxes" do
    it "returns 401 without token" do
      get "/admin/projects/#{project.id}/inboxes"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns empty list when no inboxes" do
      get "/admin/projects/#{project.id}/inboxes", headers: auth_headers
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["inboxes"]).to eq([])
      expect(body["pagination"]["total_count"]).to eq(0)
    end

    it "returns paginated inbox list" do
      3.times { |i| InboxRecord.create!(project: project, address: "inbox#{i}@test.dev") }

      get "/admin/projects/#{project.id}/inboxes", headers: auth_headers, params: {limit: 2}
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["inboxes"].size).to eq(2)
      expect(body["pagination"]["has_more"]).to be true
      expect(body["pagination"]["total_count"]).to eq(3)
    end

    it "returns 404 for non-existent project" do
      get "/admin/projects/00000000-0000-0000-0000-000000000000/inboxes", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/projects/:project_id/inboxes/:id" do
    let!(:inbox) { InboxRecord.create!(project: project, address: "show@test.dev") }

    it "returns inbox detail" do
      get "/admin/projects/#{project.id}/inboxes/#{inbox.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["inbox"]["id"]).to eq(inbox.id)
      expect(body["inbox"]["address"]).to eq("show@test.dev")
    end

    it "returns 404 for inbox in different project" do
      other_project = ProjectRecord.create!(name: "Other", slug: "other")
      get "/admin/projects/#{other_project.id}/inboxes/#{inbox.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /admin/projects/:project_id/inboxes/:id" do
    let!(:inbox) { InboxRecord.create!(project: project, address: "delete@test.dev") }

    it "deletes the inbox" do
      delete "/admin/projects/#{project.id}/inboxes/#{inbox.id}", headers: auth_headers
      expect(response).to have_http_status(:no_content)
      expect(InboxRecord.find_by(id: inbox.id)).to be_nil
    end
  end
end
