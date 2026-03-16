# frozen_string_literal: true

module Admin
  class MembersController < BaseController
    before_action :require_org_admin!, only: [:destroy]

    def index
      org = current_user.organization
      members = MembershipRecord
        .where(organization: org)
        .includes(:user)
        .order(created_at: :asc)

      render json: {
        data: members.map { |m|
          {
            id: m.id,
            user_id: m.user.id,
            email: m.user.email,
            role: m.role,
            site_admin: m.user.site_admin?,
            joined_at: m.created_at.iso8601
          }
        }
      }
    end

    def destroy
      org = current_user.organization
      membership = MembershipRecord.where(organization: org).find(params[:id])

      if membership.user_id == current_user.id
        render json: {error: "Cannot remove yourself"}, status: :unprocessable_entity
      else
        membership.destroy!
        head :no_content
      end
    end
  end
end
