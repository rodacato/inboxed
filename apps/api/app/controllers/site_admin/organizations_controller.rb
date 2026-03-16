# frozen_string_literal: true

module SiteAdmin
  class OrganizationsController < BaseController
    def index
      orgs = OrganizationRecord.order(created_at: :desc)
      render json: {
        data: orgs.map { |org|
          {
            id: org.id,
            name: org.name,
            slug: org.slug,
            trial: org.trial?,
            trial_ends_at: org.trial_ends_at&.iso8601,
            permanent: org.permanent?,
            member_count: org.memberships.count,
            project_count: org.projects.count,
            created_at: org.created_at.iso8601
          }
        }
      }
    end

    def show
      org = OrganizationRecord.find(params[:id])
      render json: {
        data: {
          id: org.id,
          name: org.name,
          slug: org.slug,
          trial: org.trial?,
          trial_ends_at: org.trial_ends_at&.iso8601,
          permanent: org.permanent?,
          days_remaining: org.days_remaining,
          member_count: org.memberships.count,
          project_count: org.projects.count,
          created_at: org.created_at.iso8601
        }
      }
    end

    def update
      org = OrganizationRecord.find(params[:id])
      org.update!(params.permit(:name))
      render json: {data: {id: org.id, name: org.name}}
    end

    def destroy
      org = OrganizationRecord.find(params[:id])
      org.destroy!
      head :no_content
    end

    def grant_permanent
      org = OrganizationRecord.find(params[:id])
      org.update!(trial_ends_at: nil)
      render json: {data: {id: org.id, permanent: true}}
    end
  end
end
