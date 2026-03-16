# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth::Invitations", type: :request do
  let!(:user_and_org) { create_authenticated_user(email: "admin@test.dev") }
  let!(:user) { user_and_org[0] }
  let!(:org) { user_and_org[1] }

  let!(:invitation) do
    InvitationRecord.create!(
      organization: org,
      email: "invitee@test.dev",
      role: "member",
      token: "valid-invitation-token",
      invited_by: user,
      expires_at: 7.days.from_now
    )
  end

  describe "GET /auth/invitation" do
    context "with a valid token" do
      it "returns 200 with invitation details" do
        get "/auth/invitation", params: {token: "valid-invitation-token"}

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["email"]).to eq("invitee@test.dev")
        expect(body["data"]["organization_name"]).to eq(org.name)
        expect(body["data"]["role"]).to eq("member")
      end
    end

    context "with an invalid token" do
      it "returns 404" do
        get "/auth/invitation", params: {token: "bogus-token"}

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invitation_not_found")
      end
    end

    context "with an expired token" do
      before { invitation.update!(expires_at: 1.day.ago) }

      it "returns 404" do
        get "/auth/invitation", params: {token: "valid-invitation-token"}

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /auth/accept-invitation" do
    it "creates a user and returns 201" do
      expect {
        post "/auth/accept-invitation",
          params: {email: "invitee@test.dev", password: "password123", token: "valid-invitation-token"},
          as: :json
      }.to change(UserRecord, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["data"]["email"]).to eq("invitee@test.dev")
    end
  end
end
