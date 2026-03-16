# frozen_string_literal: true

module Auth
  class VerificationsController < ApplicationController
    def show
      result = Inboxed::Services::VerifyUser.new.call(token: params[:token])

      if result.success?
        session[:user_id] = result.user.id
        redirect_to "/projects", allow_other_host: true
      else
        redirect_to "/login?error=invalid_verification", allow_other_host: true
      end
    end

    def create
      user = UserRecord.find_by(email: params[:email])
      if user && !user.verified?
        Inboxed::Services::SendVerificationEmail.new.call(user: user)
      end
      render json: {message: "If that email exists, we sent a verification link"}
    end
  end
end
