# frozen_string_literal: true

module Admin
  class OrganizationsController < BaseController
    before_action :require_org_admin!, only: [:update]

    def show
      org = current_user.organization
      render json: {
        data: {
          id: org.id,
          name: org.name,
          slug: org.slug,
          trial: org.trial?,
          trial_ends_at: org.trial_ends_at&.iso8601,
          trial_active: org.trial? ? org.trial_active? : nil,
          days_remaining: org.days_remaining,
          permanent: org.permanent?,
          member_count: org.memberships.count,
          project_count: org.projects.count,
          created_at: org.created_at.iso8601
        }
      }
    end

    def update
      org = current_user.organization
      org.update!(organization_params)
      render json: {data: {id: org.id, name: org.name, slug: org.slug}}
    end

    private

    def organization_params
      params.permit(:name)
    end
  end
end
