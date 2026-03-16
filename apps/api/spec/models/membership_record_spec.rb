# frozen_string_literal: true

require "rails_helper"

RSpec.describe MembershipRecord, type: :model do
  let(:user) { UserRecord.create!(email: "member@test.dev", password: "password123") }
  let(:org) { OrganizationRecord.create!(name: "Test Org", slug: "membership-test-#{SecureRandom.hex(4)}") }

  describe "validations" do
    it "allows org_admin role" do
      membership = MembershipRecord.new(user: user, organization: org, role: "org_admin")
      expect(membership).to be_valid
    end

    it "allows member role" do
      membership = MembershipRecord.new(user: user, organization: org, role: "member")
      expect(membership).to be_valid
    end

    it "rejects invalid roles" do
      membership = MembershipRecord.new(user: user, organization: org, role: "superadmin")
      expect(membership).not_to be_valid
      expect(membership.errors[:role]).to include("is not included in the list")
    end
  end

  describe "associations" do
    it "belongs to user" do
      membership = MembershipRecord.create!(user: user, organization: org, role: "member")
      expect(membership.user).to eq(user)
    end

    it "belongs to organization" do
      membership = MembershipRecord.create!(user: user, organization: org, role: "member")
      expect(membership.organization).to eq(org)
    end
  end
end
