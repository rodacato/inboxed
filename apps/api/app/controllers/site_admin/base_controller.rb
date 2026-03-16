# frozen_string_literal: true

module SiteAdmin
  class BaseController < ApplicationController
    include Paginatable
    include ErrorRenderable

    before_action :require_auth!
    before_action :require_site_admin!

    private

    def require_site_admin!
      unless current_user&.site_admin?
        render json: {error: "Forbidden"}, status: :forbidden
      end
    end
  end
end
