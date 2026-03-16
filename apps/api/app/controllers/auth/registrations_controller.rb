# frozen_string_literal: true

module Auth
  class RegistrationsController < ApplicationController
    def create
      result = Inboxed::Services::RegisterUser.new.call(
        email: params[:email],
        password: params[:password],
        invitation_token: params[:invitation_token]
      )

      if result.success?
        render json: {
          message: outbound_smtp_configured? ? "Check your email to verify your account" : "Account created",
          email: params[:email],
          auto_verified: !outbound_smtp_configured?
        }, status: :created
      else
        render json: {errors: result.errors}, status: :unprocessable_entity
      end
    rescue Inboxed::Services::RegisterUser::RegistrationClosed
      render json: {error: "registration_closed", message: "Registration is not available"}, status: :forbidden
    rescue Inboxed::Services::RegisterUser::InvitationExpired
      render json: {error: "invitation_expired", message: "This invitation has expired"}, status: :gone
    end
  end
end
