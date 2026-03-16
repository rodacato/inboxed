# frozen_string_literal: true

module Auth
  class PasswordsController < ApplicationController
    def create
      user = UserRecord.find_by(email: params[:email])
      if user&.verified?
        Inboxed::Services::SendPasswordReset.new.call(user: user)
      end
      render json: {message: "If that email exists, we sent a password reset link"}
    end

    def update
      result = Inboxed::Services::ResetPassword.new.call(
        token: params[:token],
        password: params[:password]
      )

      if result.success?
        render json: {message: "Password reset successfully"}
      else
        render json: {errors: result.errors}, status: :unprocessable_entity
      end
    end
  end
end
