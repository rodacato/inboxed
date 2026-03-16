# frozen_string_literal: true

module Admin
  class InvitationsController < BaseController
    before_action :require_org_admin!

    def index
      org = current_user.organization
      invitations = InvitationRecord
        .where(organization: org)
        .includes(:invited_by)
        .order(created_at: :desc)

      render json: {
        data: invitations.map { |inv|
          serialize_invitation(inv)
        }
      }
    end

    def create
      invitation = Inboxed::Services::InviteUser.new.call(
        organization: current_user.organization,
        email: params[:email],
        role: params[:role] || "member",
        invited_by: current_user
      )

      render json: {data: serialize_invitation(invitation)}, status: :created
    end

    def destroy
      org = current_user.organization
      invitation = InvitationRecord.where(organization: org).find(params[:id])
      invitation.destroy!
      head :no_content
    end

    private

    def serialize_invitation(inv)
      {
        id: inv.id,
        email: inv.email,
        role: inv.role,
        token: inv.token,
        accepted: inv.accepted?,
        expired: inv.expired?,
        expires_at: inv.expires_at.iso8601,
        invited_by: inv.invited_by.email,
        created_at: inv.created_at.iso8601,
        invite_url: invite_url(inv.token)
      }
    end
  end
end
