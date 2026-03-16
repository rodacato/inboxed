# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Invitations", type: :request do
  let!(:user_and_org) { create_authenticated_user(email: "admin@test.dev") }
  let!(:user) { user_and_org[0] }
  let!(:org) { user_and_org[1] }

  before { sign_in(user) }

  describe "GET /admin/invitations" do
    let!(:invitation) do
      InvitationRecord.create!(
        organization: org,
        email: "pending@test.dev",
        role: "member",
        token: SecureRandom.urlsafe_base64(32),
        invited_by: user,
        expires_at: 7.days.from_now
      )
    end

    it "lists pending invitations" do
      get "/admin/invitations"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]).to be_an(Array)
      expect(body["data"].length).to eq(1)
      expect(body["data"][0]["email"]).to eq("pending@test.dev")
      expect(body["data"][0]["role"]).to eq("member")
    end
  end

  describe "POST /admin/invitations" do
    it "creates an invitation" do
      expect {
        post "/admin/invitations", params: {email: "newmember@test.dev", role: "member"}, as: :json
      }.to change(InvitationRecord, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["data"]["email"]).to eq("newmember@test.dev")
      expect(body["data"]["role"]).to eq("member")
      expect(body["data"]).to have_key("token")
      expect(body["data"]).to have_key("invite_url")
    end
  end

  describe "DELETE /admin/invitations/:id" do
    let!(:invitation) do
      InvitationRecord.create!(
        organization: org,
        email: "revoke@test.dev",
        role: "member",
        token: SecureRandom.urlsafe_base64(32),
        invited_by: user,
        expires_at: 7.days.from_now
      )
    end

    it "revokes the invitation" do
      expect {
        delete "/admin/invitations/#{invitation.id}"
      }.to change(InvitationRecord, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
