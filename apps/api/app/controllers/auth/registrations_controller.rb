# frozen_string_literal: true

module Auth
  class RegistrationsController < ApplicationController
    before_action :verify_turnstile!, only: [:create]

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

    private

    def verify_turnstile!
      secret = ENV["TURNSTILE_SECRET_KEY"]
      return unless secret.present? # Skip if not configured

      token = params[:turnstile_token]
      unless token.present?
        return render json: {error: "captcha_required", message: "Please complete the captcha"}, status: :unprocessable_entity
      end

      response = Net::HTTP.post_form(
        URI("https://challenges.cloudflare.com/turnstile/v0/siteverify"),
        {secret: secret, response: token, remoteip: request.remote_ip}
      )
      result = JSON.parse(response.body)

      unless result["success"]
        render json: {error: "captcha_failed", message: "Captcha verification failed. Please try again."}, status: :unprocessable_entity
      end
    end
  end
end
