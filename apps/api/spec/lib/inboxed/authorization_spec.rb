# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::Authorization do
  let(:org) { OrganizationRecord.create!(name: "Auth Org", slug: "auth-org-#{SecureRandom.hex(4)}", trial_ends_at: nil) }

  def build_auth(user:, organization: org)
    described_class.new(user: user, organization: organization)
  end

  describe "role-based permissions" do
    context "site_admin" do
      let(:user) { UserRecord.create!(email: "siteadmin@test.dev", password: "password123", site_admin: true) }

      before { MembershipRecord.create!(user: user, organization: org, role: "org_admin") }

      it "can perform all actions" do
        auth = build_auth(user: user)

        %i[view_data create_project delete_project manage_api_keys invite_members
          remove_members manage_org manage_instance grant_permanent].each do |action|
          expect(auth.can?(action)).to be(true), "Expected site_admin to be able to #{action}"
        end
      end
    end

    context "org_admin" do
      let(:user) { UserRecord.create!(email: "orgadmin@test.dev", password: "password123") }

      before { MembershipRecord.create!(user: user, organization: org, role: "org_admin") }

      it "can perform org-level actions" do
        auth = build_auth(user: user)

        %i[view_data create_project delete_project manage_api_keys invite_members
          remove_members manage_org].each do |action|
          expect(auth.can?(action)).to be(true), "Expected org_admin to be able to #{action}"
        end
      end

      it "cannot perform instance-level actions" do
        auth = build_auth(user: user)

        %i[manage_instance grant_permanent].each do |action|
          expect(auth.can?(action)).to be(false), "Expected org_admin NOT to be able to #{action}"
        end
      end
    end

    context "member" do
      let(:user) { UserRecord.create!(email: "member@test.dev", password: "password123") }

      before { MembershipRecord.create!(user: user, organization: org, role: "member") }

      it "can view data" do
        auth = build_auth(user: user)
        expect(auth.can?(:view_data)).to be true
      end

      it "cannot perform write actions" do
        auth = build_auth(user: user)

        %i[create_project delete_project manage_api_keys invite_members
          remove_members manage_org manage_instance grant_permanent].each do |action|
          expect(auth.can?(action)).to be(false), "Expected member NOT to be able to #{action}"
        end
      end
    end
  end

  describe "trial expired behavior" do
    let(:expired_org) do
      OrganizationRecord.create!(name: "Expired Org", slug: "expired-org-#{SecureRandom.hex(4)}", trial_ends_at: 1.day.ago)
    end

    let(:user) { UserRecord.create!(email: "trialuser@test.dev", password: "password123") }

    before { MembershipRecord.create!(user: user, organization: expired_org, role: "org_admin") }

    it "allows view_data even when trial expired" do
      auth = build_auth(user: user, organization: expired_org)
      expect(auth.can?(:view_data)).to be true
    end

    it "blocks write actions when trial expired" do
      auth = build_auth(user: user, organization: expired_org)

      %i[create_project delete_project manage_api_keys invite_members
        remove_members manage_org].each do |action|
        expect(auth.can?(action)).to be(false), "Expected #{action} to be blocked for expired trial"
      end
    end
  end
end
