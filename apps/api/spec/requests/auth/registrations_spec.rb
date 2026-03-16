# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth::Registrations", type: :request do
  describe "POST /auth/register" do
    context "with REGISTRATION_MODE=open" do
      before { ENV["REGISTRATION_MODE"] = "open" }
      after { ENV.delete("REGISTRATION_MODE") }

      it "returns 201 and creates a user" do
        expect {
          post "/auth/register", params: {email: "new@test.dev", password: "password123"}, as: :json
        }.to change(UserRecord, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["email"]).to eq("new@test.dev")
      end
    end

    context "with REGISTRATION_MODE=closed" do
      before { ENV["REGISTRATION_MODE"] = "closed" }
      after { ENV.delete("REGISTRATION_MODE") }

      it "returns 403" do
        post "/auth/register", params: {email: "new@test.dev", password: "password123"}, as: :json

        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("registration_closed")
      end
    end

    context "with invalid data" do
      before { ENV["REGISTRATION_MODE"] = "open" }
      after { ENV.delete("REGISTRATION_MODE") }

      it "returns 422 with missing password" do
        post "/auth/register", params: {email: "new@test.dev", password: ""}, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns 422 with invalid email" do
        post "/auth/register", params: {email: "not-an-email", password: "password123"}, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
