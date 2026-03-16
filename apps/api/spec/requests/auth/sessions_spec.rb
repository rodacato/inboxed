# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth::Sessions", type: :request do
  let!(:user_and_org) { create_authenticated_user(email: "user@test.dev", password: "password123") }
  let!(:user) { user_and_org[0] }
  let!(:org) { user_and_org[1] }

  describe "POST /auth/sessions" do
    context "with valid credentials" do
      it "returns 200 and user data" do
        post "/auth/sessions", params: {email: "user@test.dev", password: "password123"}, as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["email"]).to eq("user@test.dev")
        expect(body["data"]).to have_key("id")
        expect(body["data"]).to have_key("organization")
      end
    end

    context "with invalid credentials" do
      it "returns 401" do
        post "/auth/sessions", params: {email: "user@test.dev", password: "wrongpassword"}, as: :json

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invalid_credentials")
      end
    end

    context "with nonexistent email" do
      it "returns 401" do
        post "/auth/sessions", params: {email: "nobody@test.dev", password: "password123"}, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with unverified user when SMTP is configured" do
      before do
        user.update!(verified_at: nil)
        ENV["OUTBOUND_SMTP_HOST"] = "smtp.test.dev"
      end

      after do
        ENV.delete("OUTBOUND_SMTP_HOST")
      end

      it "returns 403 with email_not_verified error" do
        post "/auth/sessions", params: {email: "user@test.dev", password: "password123"}, as: :json

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("email_not_verified")
      end
    end
  end

  describe "GET /auth/me" do
    context "with an active session" do
      before { sign_in(user) }

      it "returns 200 with user data" do
        get "/auth/me"

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["email"]).to eq("user@test.dev")
        expect(body["data"]).to have_key("organization")
      end
    end

    context "without a session" do
      it "returns 401" do
        get "/auth/me"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /auth/sessions" do
    before { sign_in(user) }

    it "returns 204 and clears the session" do
      delete "/auth/sessions"

      expect(response).to have_http_status(:no_content)

      get "/auth/me"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
