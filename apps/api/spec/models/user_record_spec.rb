# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserRecord, type: :model do
  describe "validations" do
    it "validates email presence" do
      user = UserRecord.new(email: nil, password: "password123")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "validates email uniqueness" do
      UserRecord.create!(email: "taken@test.dev", password: "password123")
      user = UserRecord.new(email: "taken@test.dev", password: "password123")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("has already been taken")
    end

    it "validates email format" do
      user = UserRecord.new(email: "not-an-email", password: "password123")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("is invalid")
    end

    it "validates password length >= 8 on create" do
      user = UserRecord.new(email: "short@test.dev", password: "short")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("is too short (minimum is 8 characters)")
    end

    it "accepts valid attributes" do
      user = UserRecord.new(email: "valid@test.dev", password: "password123")
      expect(user).to be_valid
    end
  end

  describe "has_secure_password" do
    it "authenticates with correct password" do
      user = UserRecord.create!(email: "auth@test.dev", password: "password123")
      expect(user.authenticate("password123")).to eq(user)
    end

    it "fails authentication with wrong password" do
      user = UserRecord.create!(email: "auth2@test.dev", password: "password123")
      expect(user.authenticate("wrong")).to be false
    end
  end

  describe "#verified?" do
    it "returns true when verified_at is set" do
      user = UserRecord.new(verified_at: Time.current)
      expect(user.verified?).to be true
    end

    it "returns false when verified_at is nil" do
      user = UserRecord.new(verified_at: nil)
      expect(user.verified?).to be false
    end
  end

  describe "#site_admin?" do
    it "returns true when site_admin is true" do
      user = UserRecord.new(site_admin: true)
      expect(user.site_admin?).to be true
    end

    it "returns false when site_admin is false" do
      user = UserRecord.new(site_admin: false)
      expect(user.site_admin?).to be false
    end
  end

  describe "#role_in" do
    let(:org) { OrganizationRecord.create!(name: "Test Org", slug: "role-test-#{SecureRandom.hex(4)}") }

    it "returns 'site_admin' if user is site_admin regardless of membership" do
      user = UserRecord.create!(email: "admin@test.dev", password: "password123", site_admin: true)
      MembershipRecord.create!(user: user, organization: org, role: "member")
      expect(user.role_in(org)).to eq("site_admin")
    end

    it "returns the membership role when user is not site_admin" do
      user = UserRecord.create!(email: "member@test.dev", password: "password123", site_admin: false)
      MembershipRecord.create!(user: user, organization: org, role: "org_admin")
      expect(user.role_in(org)).to eq("org_admin")
    end

    it "returns 'member' when no membership exists" do
      user = UserRecord.create!(email: "nomember@test.dev", password: "password123", site_admin: false)
      expect(user.role_in(org)).to eq("member")
    end
  end

  describe "#organization" do
    it "returns the first organization" do
      user = UserRecord.create!(email: "orgtest@test.dev", password: "password123")
      org = OrganizationRecord.create!(name: "First Org", slug: "first-org-#{SecureRandom.hex(4)}")
      MembershipRecord.create!(user: user, organization: org, role: "member")

      expect(user.organization).to eq(org)
    end
  end
end
