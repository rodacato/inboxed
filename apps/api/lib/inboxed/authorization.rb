# frozen_string_literal: true

module Inboxed
  class Authorization
    PERMISSIONS = {
      view_data: %w[site_admin org_admin member],
      create_project: %w[site_admin org_admin],
      delete_project: %w[site_admin org_admin],
      manage_api_keys: %w[site_admin org_admin],
      invite_members: %w[site_admin org_admin],
      remove_members: %w[site_admin org_admin],
      manage_org: %w[site_admin org_admin],
      manage_instance: %w[site_admin],
      grant_permanent: %w[site_admin]
    }.freeze

    def initialize(user:, organization:)
      @user = user
      @org = organization
      @role = user.role_in(organization)
    end

    def can?(action)
      return false if trial_expired? && write_action?(action)
      PERMISSIONS.fetch(action, []).include?(@role)
    end

    def trial_expired?
      @org.trial_expired?
    end

    private

    def write_action?(action)
      !%i[view_data].include?(action)
    end
  end
end
