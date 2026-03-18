# frozen_string_literal: true

# Blocks resource creation if the user's email is not verified.
# Only enforced when outbound SMTP is configured (otherwise users are auto-verified).
module VerificationEnforced
  extend ActiveSupport::Concern

  private

  def enforce_email_verified!
    return unless current_user
    return if current_user.verified?

    render json: {
      error: "email_not_verified",
      message: "Please verify your email address before creating resources."
    }, status: :forbidden
  end
end
