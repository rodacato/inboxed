# frozen_string_literal: true

module Auth
  class InvitationsController < ApplicationController
    def show
      invitation = InvitationRecord.pending.find_by(token: params[:token])

      if invitation
        render json: {
          data: {
            email: invitation.email,
            organization_name: invitation.organization.name,
            role: invitation.role,
            expires_at: invitation.expires_at.iso8601
          }
        }
      else
        render json: {error: "invitation_not_found"}, status: :not_found
      end
    end

    def accept
      result = Inboxed::Services::RegisterUser.new.call(
        email: params[:email],
        password: params[:password],
        invitation_token: params[:token]
      )

      if result.success?
        session[:user_id] = result.user.id
        render json: {data: serialize_user_with_org(result.user)}, status: :created
      else
        render json: {errors: result.errors}, status: :unprocessable_entity
      end
    rescue Inboxed::Services::RegisterUser::InvitationExpired
      render json: {error: "invitation_expired"}, status: :gone
    end
  end
end
