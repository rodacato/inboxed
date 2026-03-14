require "rails_helper"

RSpec.describe "Api::V1::Status", type: :request do
  describe "GET /api/v1/status" do
    context "without API key" do
      it "returns 401" do
        get "/api/v1/status"
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["code"]).to eq("unauthorized")
      end
    end

    context "with API key" do
      it "returns 200 with status info" do
        get "/api/v1/status", headers: {"Authorization" => "Bearer test-api-key"}

        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body["service"]).to eq("inboxed-api")
        expect(body["version"]).to eq("0.0.1")
        expect(body["status"]).to eq("ok")
        expect(body["timestamp"]).to be_present
      end
    end
  end
end
