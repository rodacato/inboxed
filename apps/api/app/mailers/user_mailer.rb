# frozen_string_literal: true

class UserMailer < ApplicationMailer
  default from: -> { ENV.fetch("OUTBOUND_FROM_EMAIL", "noreply@inboxed.dev") }

  def verification(user)
    @user = user
    @url = "#{base_url}/auth/verify?token=#{user.verification_token}"
    mail(to: user.email, subject: "Verify your Inboxed account")
  end

  def password_reset(user)
    @user = user
    @url = "#{base_url}/reset-password?token=#{user.password_reset_token}"
    mail(to: user.email, subject: "Reset your Inboxed password")
  end

  private

  def base_url
    ENV.fetch("INBOXED_BASE_URL", "http://localhost:5179")
  end
end
