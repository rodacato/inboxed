# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inboxed::CurrentTenant do
  let(:org) { OrganizationRecord.create!(name: "Tenant Org", slug: "tenant-org-#{SecureRandom.hex(4)}") }
  let(:user) { UserRecord.create!(email: "tenant@test.dev", password: "password123") }

  before do
    MembershipRecord.create!(user: user, organization: org, role: "org_admin")
  end

  describe ".set" do
    it "establishes thread-local state within the block" do
      described_class.set(user: user, organization: org) do
        expect(described_class.organization_id).to eq(org.id)
        expect(described_class.user_id).to eq(user.id)
        expect(described_class.user_role).to eq("org_admin")
      end
    end

    it "clears thread-local state after the block" do
      described_class.set(user: user, organization: org) {}

      expect(described_class.organization_id).to be_nil
      expect(described_class.user_id).to be_nil
      expect(described_class.user_role).to be_nil
    end

    it "clears state even when block raises" do
      begin
        described_class.set(user: user, organization: org) { raise "boom" }
      rescue RuntimeError
        # expected
      end

      expect(described_class.organization_id).to be_nil
    end
  end

  describe ".scope_projects" do
    let!(:project_in_org) do
      ProjectRecord.create!(name: "In Org", slug: "in-org-#{SecureRandom.hex(4)}", organization: org, default_ttl_hours: 24)
    end

    let(:other_org) { OrganizationRecord.create!(name: "Other Org", slug: "other-org-#{SecureRandom.hex(4)}") }
    let!(:project_other_org) do
      ProjectRecord.create!(name: "Other", slug: "other-#{SecureRandom.hex(4)}", organization: other_org, default_ttl_hours: 24)
    end

    it "scopes projects by org_id" do
      described_class.set(user: user, organization: org) do
        result = described_class.scope_projects(ProjectRecord.all)
        expect(result).to include(project_in_org)
        expect(result).not_to include(project_other_org)
      end
    end

    it "raises TenantNotSet when not set" do
      expect {
        described_class.scope_projects(ProjectRecord.all)
      }.to raise_error(Inboxed::CurrentTenant::TenantNotSet)
    end

    it "returns all projects for site_admin" do
      admin = UserRecord.create!(email: "siteadmin@test.dev", password: "password123", site_admin: true)
      MembershipRecord.create!(user: admin, organization: org, role: "org_admin")

      described_class.set(user: admin, organization: org) do
        result = described_class.scope_projects(ProjectRecord.all)
        expect(result).to include(project_in_org)
        expect(result).to include(project_other_org)
      end
    end
  end

  describe ".set?" do
    it "returns false when not set" do
      expect(described_class.set?).to be false
    end

    it "returns true when set" do
      described_class.set(user: user, organization: org) do
        expect(described_class.set?).to be true
      end
    end
  end

  describe ".site_admin?" do
    it "returns true for site_admin user" do
      admin = UserRecord.create!(email: "siteadmin2@test.dev", password: "password123", site_admin: true)
      MembershipRecord.create!(user: admin, organization: org, role: "org_admin")

      described_class.set(user: admin, organization: org) do
        expect(described_class.site_admin?).to be true
      end
    end

    it "returns false for non-site_admin user" do
      described_class.set(user: user, organization: org) do
        expect(described_class.site_admin?).to be false
      end
    end
  end

  describe ".org_admin?" do
    it "returns true for org_admin" do
      described_class.set(user: user, organization: org) do
        expect(described_class.org_admin?).to be true
      end
    end

    it "returns true for site_admin" do
      admin = UserRecord.create!(email: "siteadmin3@test.dev", password: "password123", site_admin: true)
      MembershipRecord.create!(user: admin, organization: org, role: "org_admin")

      described_class.set(user: admin, organization: org) do
        expect(described_class.org_admin?).to be true
      end
    end

    it "returns false for member" do
      member = UserRecord.create!(email: "member@test.dev", password: "password123")
      MembershipRecord.create!(user: member, organization: org, role: "member")

      described_class.set(user: member, organization: org) do
        expect(described_class.org_admin?).to be false
      end
    end
  end
end
