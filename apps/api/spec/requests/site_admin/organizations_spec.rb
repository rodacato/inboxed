# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SiteAdmin::Organizations", type: :request do
  describe "access control" do
    context "as a non-site-admin user" do
      let!(:user_and_org) { create_authenticated_user(email: "regular@test.dev", site_admin: false) }
      let!(:user) { user_and_org[0] }

      before { sign_in(user) }

      it "returns 403" do
        get "/site_admin/organizations"

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  context "as a site admin" do
    let!(:admin_and_org) { create_authenticated_user(email: "siteadmin@test.dev", site_admin: true) }
    let!(:admin) { admin_and_org[0] }
    let!(:admin_org) { admin_and_org[1] }

    before { sign_in(admin) }

    describe "GET /site_admin/organizations" do
      it "lists all organizations" do
        get "/site_admin/organizations"

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]).to be_an(Array)
        expect(body["data"].length).to be >= 1
        expect(body["data"][0]).to have_key("name")
        expect(body["data"][0]).to have_key("slug")
      end
    end

    describe "POST /site_admin/organizations/:id/grant_permanent" do
      let!(:trial_org) do
        OrganizationRecord.create!(
          name: "Trial Org",
          slug: "trial-org-#{SecureRandom.hex(4)}",
          trial_ends_at: 14.days.from_now
        )
      end

      it "sets trial_ends_at to nil (grants permanent access)" do
        post "/site_admin/organizations/#{trial_org.id}/grant_permanent"

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["permanent"]).to be true

        trial_org.reload
        expect(trial_org.trial_ends_at).to be_nil
      end
    end
  end
end
