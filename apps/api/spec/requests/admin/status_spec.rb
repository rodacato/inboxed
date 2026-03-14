require "rails_helper"

RSpec.describe "Admin::Status", type: :request do
  describe "GET /admin/status" do
    context "without token" do
      it "returns 401" do
        get "/admin/status"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid token" do
      it "returns 401" do
        get "/admin/status", headers: {"Authorization" => "Bearer wrong-token"}
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with valid admin token" do
      before do
        ENV["INBOXED_ADMIN_TOKEN"] = "test-admin-token"
      end

      after do
        ENV.delete("INBOXED_ADMIN_TOKEN")
      end

      it "returns 200 with extended status info" do
        get "/admin/status", headers: {"Authorization" => "Bearer test-admin-token"}

        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body["service"]).to eq("inboxed-api")
        expect(body["status"]).to eq("ok")
        expect(body["environment"]).to eq("test")
        expect(body["database"]).to eq("connected")
      end
    end
  end
end
