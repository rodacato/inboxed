# frozen_string_literal: true

module Auth
  class SessionsController < ApplicationController
    def create
      user = UserRecord.find_by(email: params[:email]&.downcase&.strip)

      if user&.authenticate(params[:password])
        if outbound_smtp_configured? && !user.verified?
          render json: {error: "email_not_verified", message: "Please verify your email first"}, status: :forbidden
        else
          start_session(user)
          render json: {data: serialize_user_with_org(user)}
        end
      else
        render json: {error: "invalid_credentials"}, status: :unauthorized
      end
    end

    def show
      if current_user
        render json: {data: serialize_user_with_org(current_user)}
      else
        head :unauthorized
      end
    end

    def destroy
      reset_session
      head :no_content
    end

    private

    def start_session(user)
      session[:user_id] = user.id
      user.update!(
        last_sign_in_at: Time.current,
        sign_in_count: user.sign_in_count + 1
      )
    end
  end
end
