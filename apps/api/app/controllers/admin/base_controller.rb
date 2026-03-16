# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    include Paginatable
    include ErrorRenderable

    around_action :with_tenant
    before_action :require_auth!

    private

    def current_project
      Inboxed::CurrentTenant.scope_projects(ProjectRecord).find(params[:project_id])
    end

    def require_org_admin!
      unless Inboxed::CurrentTenant.org_admin?
        render json: {error: "Forbidden"}, status: :forbidden
      end
    end

    def invite_url(token)
      "#{ENV.fetch("INBOXED_BASE_URL", "http://localhost:5179")}/invitation?token=#{token}"
    end
  end
end
