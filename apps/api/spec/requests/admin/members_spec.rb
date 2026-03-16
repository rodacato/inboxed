# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Members", type: :request do
  let!(:user_and_org) { create_authenticated_user(email: "admin@test.dev") }
  let!(:user) { user_and_org[0] }
  let!(:org) { user_and_org[1] }

  before { sign_in(user) }

  describe "GET /admin/members" do
    it "lists organization members" do
      get "/admin/members"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]).to be_an(Array)
      expect(body["data"].length).to eq(1)
      expect(body["data"][0]["email"]).to eq("admin@test.dev")
      expect(body["data"][0]["role"]).to eq("org_admin")
    end
  end

  describe "DELETE /admin/members/:id" do
    context "removing another member" do
      let!(:other_user) do
        u = UserRecord.create!(email: "member@test.dev", password: "password123", verified_at: Time.current)
        MembershipRecord.create!(user: u, organization: org, role: "member")
        u
      end

      it "removes the member and returns 204" do
        membership = MembershipRecord.find_by(user: other_user, organization: org)

        expect {
          delete "/admin/members/#{membership.id}"
        }.to change(MembershipRecord, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "removing self" do
      it "returns 422" do
        membership = MembershipRecord.find_by(user: user, organization: org)

        delete "/admin/members/#{membership.id}"

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to include("Cannot remove yourself")
      end
    end
  end
end
