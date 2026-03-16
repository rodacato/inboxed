# frozen_string_literal: true

module Inboxed
  class CurrentTenant
    thread_mattr_accessor :organization_id, :user_id, :user_role

    def self.set(user:, organization:)
      self.user_id = user.id
      self.organization_id = organization.id
      self.user_role = user.role_in(organization)
      yield
    ensure
      self.user_id = nil
      self.organization_id = nil
      self.user_role = nil
    end

    def self.scope_projects(relation)
      return relation if site_admin?
      raise TenantNotSet unless set?
      relation.where(organization_id: organization_id)
    end

    def self.set? = organization_id.present?

    def self.site_admin? = user_role == "site_admin"

    def self.org_admin? = user_role.in?(%w[site_admin org_admin])

    class TenantNotSet < StandardError; end
  end
end
