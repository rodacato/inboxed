# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Trial Enforcement", type: :request do
  let!(:user_and_org) { create_authenticated_user(email: "trial@test.dev") }
  let!(:user) { user_and_org[0] }
  let!(:org) { user_and_org[1] }
  let!(:project) { ProjectRecord.create!(name: "Trial Project", slug: "trial-proj-#{SecureRandom.hex(4)}", organization: org) }
  let!(:inbox) { InboxRecord.create!(project: project, address: "trial@test.dev") }

  before { sign_in(user) }

  context "with expired trial" do
    before do
      org.update!(trial_ends_at: 1.day.ago)
    end

    # --- Projects ---

    it "blocks project creation" do
      post "/admin/projects", params: {project: {name: "New", slug: "new-#{SecureRandom.hex(4)}"}}, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "allows project listing (read)" do
      get "/admin/projects"
      expect(response).to have_http_status(:ok)
    end

    # --- Endpoints ---

    it "blocks endpoint creation" do
      post "/admin/projects/#{project.id}/endpoints",
        params: {endpoint_type: "webhook", label: "New Hook"}, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "allows endpoint listing (read)" do
      get "/admin/projects/#{project.id}/endpoints"
      expect(response).to have_http_status(:ok)
    end

    # --- API Keys ---

    it "blocks API key creation" do
      post "/admin/projects/#{project.id}/api_keys",
        params: {api_key: {label: "New Key"}}, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "allows API key listing (read)" do
      get "/admin/projects/#{project.id}/api_keys"
      expect(response).to have_http_status(:ok)
    end

    # --- Inboxes ---

    it "blocks inbox deletion" do
      delete "/admin/projects/#{project.id}/inboxes/#{inbox.id}"
      expect(response).to have_http_status(:forbidden)
      expect(InboxRecord.find_by(id: inbox.id)).to be_present
    end

    it "allows inbox listing (read)" do
      get "/admin/projects/#{project.id}/inboxes"
      expect(response).to have_http_status(:ok)
    end
  end

  context "with active trial" do
    before do
      org.update!(trial_ends_at: 7.days.from_now)
    end

    it "allows project creation" do
      post "/admin/projects", params: {project: {name: "Allowed", slug: "allowed-#{SecureRandom.hex(4)}"}}, as: :json
      expect(response).to have_http_status(:created)
    end

    it "allows endpoint creation" do
      post "/admin/projects/#{project.id}/endpoints",
        params: {endpoint_type: "webhook", label: "Allowed Hook"}, as: :json
      expect(response).to have_http_status(:created)
    end

    it "allows API key creation" do
      post "/admin/projects/#{project.id}/api_keys",
        params: {api_key: {label: "Allowed Key"}}, as: :json
      expect(response).to have_http_status(:created)
    end
  end

  context "with permanent org (no trial)" do
    before do
      org.update!(trial_ends_at: nil)
    end

    it "allows all write operations" do
      post "/admin/projects", params: {project: {name: "Permanent", slug: "perm-#{SecureRandom.hex(4)}"}}, as: :json
      expect(response).to have_http_status(:created)
    end
  end
end
