# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SiteAdmin::Users", type: :request do
  let!(:admin_and_org) { create_authenticated_user(email: "siteadmin@test.dev", site_admin: true) }
  let!(:admin) { admin_and_org[0] }
  let!(:admin_org) { admin_and_org[1] }

  before { sign_in(admin) }

  describe "GET /site_admin/users" do
    it "lists all users" do
      get "/site_admin/users"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]).to be_an(Array)
      expect(body["data"].length).to be >= 1
      expect(body["data"][0]).to have_key("email")
      expect(body["data"][0]).to have_key("site_admin")
    end
  end

  describe "DELETE /site_admin/users/:id" do
    context "deleting another user" do
      let!(:other_user) do
        UserRecord.create!(email: "other@test.dev", password: "password123", verified_at: Time.current)
      end

      it "deletes the user and returns 204" do
        expect {
          delete "/site_admin/users/#{other_user.id}"
        }.to change(UserRecord, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "deleting self" do
      it "returns 422" do
        delete "/site_admin/users/#{admin.id}"

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to include("Cannot delete yourself")
      end
    end
  end
end
