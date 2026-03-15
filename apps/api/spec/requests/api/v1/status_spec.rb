require "rails_helper"

RSpec.describe "Api::V1::Status", type: :request do
  describe "GET /api/v1/status" do
    context "without API key" do
      it "returns 401" do
        get "/api/v1/status"
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("API key required")
      end
    end

    context "with API key" do
      it "returns 200 with status info" do
        project = ProjectRecord.create!(
          id: SecureRandom.uuid,
          name: "Test",
          slug: "test"
        )
        token = SecureRandom.hex(32)
        ApiKeyRecord.create!(
          id: SecureRandom.uuid,
          project_id: project.id,
          token_prefix: token[0, 8],
          token_digest: BCrypt::Password.create(token),
          label: "test"
        )

        get "/api/v1/status", headers: {"Authorization" => "Bearer #{token}"}

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
