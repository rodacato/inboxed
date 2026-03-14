module Admin
  class BaseController < ApplicationController
    before_action :authenticate_admin!

    private

    def authenticate_admin!
      token = extract_bearer_token
      admin_token = ENV["INBOXED_ADMIN_TOKEN"]

      if token.blank? || admin_token.blank? || !ActiveSupport::SecurityUtils.secure_compare(token, admin_token)
        render json: {error: "Invalid admin token", code: "unauthorized"}, status: :unauthorized
      end
    end

    def extract_bearer_token
      request.headers["Authorization"]&.match(/\ABearer\s+(.+)\z/)&.captures&.first
    end
  end
end
