# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Inboxes", type: :request do
  let!(:user_and_org) { create_authenticated_user }
  let!(:user) { user_and_org[0] }
  let!(:org) { user_and_org[1] }
  before { sign_in(user) }

  let!(:project) { ProjectRecord.create!(name: "Test Project", slug: "test-project", organization: org) }

  describe "GET /admin/projects/:project_id/inboxes" do
    it "returns 401 without session" do
      reset!
      get "/admin/projects/#{project.id}/inboxes"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns empty list when no inboxes" do
      get "/admin/projects/#{project.id}/inboxes"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["inboxes"]).to eq([])
      expect(body["pagination"]["total_count"]).to eq(0)
    end

    it "returns paginated inbox list" do
      3.times { |i| InboxRecord.create!(project: project, address: "inbox#{i}@test.dev") }

      get "/admin/projects/#{project.id}/inboxes", params: {limit: 2}
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["inboxes"].size).to eq(2)
      expect(body["pagination"]["has_more"]).to be true
      expect(body["pagination"]["total_count"]).to eq(3)
    end

    it "returns 404 for non-existent project" do
      get "/admin/projects/00000000-0000-0000-0000-000000000000/inboxes"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/projects/:project_id/inboxes/:id" do
    let!(:inbox) { InboxRecord.create!(project: project, address: "show@test.dev") }

    it "returns inbox detail" do
      get "/admin/projects/#{project.id}/inboxes/#{inbox.id}"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["inbox"]["id"]).to eq(inbox.id)
      expect(body["inbox"]["address"]).to eq("show@test.dev")
    end

    it "returns 404 for inbox in different project" do
      other_project = ProjectRecord.create!(name: "Other", slug: "other", organization: org)
      get "/admin/projects/#{other_project.id}/inboxes/#{inbox.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /admin/projects/:project_id/inboxes/:id" do
    let!(:inbox) { InboxRecord.create!(project: project, address: "delete@test.dev") }

    it "deletes the inbox" do
      delete "/admin/projects/#{project.id}/inboxes/#{inbox.id}"
      expect(response).to have_http_status(:no_content)
      expect(InboxRecord.find_by(id: inbox.id)).to be_nil
    end
  end
end
