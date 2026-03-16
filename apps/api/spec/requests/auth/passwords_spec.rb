# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth::Passwords", type: :request do
  describe "POST /auth/forgot-password" do
    it "returns 200 regardless of whether email exists (for security)" do
      post "/auth/forgot-password", params: {email: "nonexistent@test.dev"}, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["message"]).to include("If that email exists")
    end

    it "returns 200 for an existing user" do
      create_authenticated_user(email: "exists@test.dev")

      post "/auth/forgot-password", params: {email: "exists@test.dev"}, as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PUT /auth/reset-password" do
    context "with a valid token" do
      let!(:user_and_org) { create_authenticated_user(email: "reset@test.dev") }
      let!(:user) { user_and_org[0] }

      before do
        user.update!(
          password_reset_token: "valid-reset-token",
          password_reset_sent_at: Time.current
        )
      end

      it "returns 200 and resets the password" do
        put "/auth/reset-password", params: {token: "valid-reset-token", password: "newpassword123"}, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["message"]).to include("Password reset successfully")

        user.reload
        expect(user.read_attribute(:password_reset_token)).to be_nil
      end
    end

    context "with an invalid token" do
      it "returns 422" do
        put "/auth/reset-password", params: {token: "bogus-token", password: "newpassword123"}, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
