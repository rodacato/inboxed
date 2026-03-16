# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Setup", type: :request do
  before do
    ENV["INBOXED_SETUP_TOKEN"] = "test-token"
  end

  after do
    ENV.delete("INBOXED_SETUP_TOKEN")
  end

  describe "GET /setup" do
    context "when setup is not completed" do
      it "returns 200 with setup_required: true" do
        get "/setup"

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["setup_required"]).to be true
      end
    end

    context "when setup is already completed" do
      before { Inboxed::Settings.set(:setup_completed_at, Time.current) }

      it "returns 200 with setup_required: false" do
        get "/setup"

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["setup_required"]).to be false
      end
    end
  end

  describe "POST /setup" do
    context "with a valid setup token" do
      it "returns 201 and creates the admin user" do
        expect {
          post "/setup", params: {
            setup_token: "test-token",
            email: "admin@inboxed.dev",
            password: "password123",
            org_name: "My Org"
          }, as: :json
        }.to change(UserRecord, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["data"]["email"]).to eq("admin@inboxed.dev")
        expect(body["data"]["site_admin"]).to be true
      end
    end

    context "with an invalid setup token" do
      it "returns 403" do
        post "/setup", params: {
          setup_token: "wrong-token",
          email: "admin@inboxed.dev",
          password: "password123"
        }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when setup is already completed" do
      before { Inboxed::Settings.set(:setup_completed_at, Time.current) }

      it "returns setup_required: false and blocks creation" do
        expect {
          post "/setup", params: {
            setup_token: "test-token",
            email: "admin@inboxed.dev",
            password: "password123"
          }, as: :json
        }.not_to change(UserRecord, :count)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["setup_required"]).to be false
      end
    end
  end
end
