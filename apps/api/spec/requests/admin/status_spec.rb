# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Status", type: :request do
  describe "GET /admin/status" do
    context "without session" do
      it "returns 200 with public status info (no user/org)" do
        get "/admin/status"
        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body).to have_key("setup_completed")
        expect(body).to have_key("features")
        expect(body).not_to have_key("user")
        expect(body).not_to have_key("organization")
      end
    end

    context "with authenticated session" do
      let!(:user_and_org) { create_authenticated_user }
      let!(:user) { user_and_org[0] }
      let!(:org) { user_and_org[1] }
      before { sign_in(user) }

      it "returns 200 with status info" do
        get "/admin/status"

        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body).to have_key("setup_completed")
        expect(body).to have_key("registration_mode")
        expect(body).to have_key("features")
        expect(body).to have_key("user")
        expect(body).to have_key("organization")
      end
    end
  end
end
