# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    include Paginatable
    include ErrorRenderable

    before_action :authenticate_admin!

    private

    def authenticate_admin!
      token = extract_bearer_token
      admin_token = ENV["INBOXED_ADMIN_TOKEN"]

      if token.blank? || admin_token.blank? || !ActiveSupport::SecurityUtils.secure_compare(token, admin_token)
        render_unauthorized("Invalid admin token")
      end
    end

    def extract_bearer_token
      request.headers["Authorization"]&.match(/\ABearer\s+(.+)\z/)&.captures&.first
    end
  end
end
