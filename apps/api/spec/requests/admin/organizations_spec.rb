# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Organizations", type: :request do
  let!(:user_and_org) { create_authenticated_user(email: "admin@test.dev") }
  let!(:user) { user_and_org[0] }
  let!(:org) { user_and_org[1] }

  before { sign_in(user) }

  describe "GET /admin/organization" do
    it "returns organization details" do
      get "/admin/organization"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["id"]).to eq(org.id)
      expect(body["data"]["name"]).to eq(org.name)
      expect(body["data"]["slug"]).to eq(org.slug)
      expect(body["data"]).to have_key("member_count")
      expect(body["data"]).to have_key("project_count")
    end
  end

  describe "PATCH /admin/organization" do
    it "updates the organization name" do
      patch "/admin/organization", params: {name: "Updated Org Name"}, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["name"]).to eq("Updated Org Name")

      org.reload
      expect(org.name).to eq("Updated Org Name")
    end
  end
end
