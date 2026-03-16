# frozen_string_literal: true

module SiteAdmin
  class UsersController < BaseController
    def index
      users = UserRecord.order(created_at: :desc)
      render json: {
        data: users.map { |u|
          {
            id: u.id,
            email: u.email,
            site_admin: u.site_admin?,
            verified: u.verified?,
            organization: u.organization&.name,
            last_sign_in_at: u.last_sign_in_at&.iso8601,
            created_at: u.created_at.iso8601
          }
        }
      }
    end

    def show
      user = UserRecord.find(params[:id])
      render json: {
        data: {
          id: user.id,
          email: user.email,
          site_admin: user.site_admin?,
          verified: user.verified?,
          organization: user.organization&.name,
          sign_in_count: user.sign_in_count,
          last_sign_in_at: user.last_sign_in_at&.iso8601,
          created_at: user.created_at.iso8601
        }
      }
    end

    def destroy
      user = UserRecord.find(params[:id])
      if user.id == current_user.id
        render json: {error: "Cannot delete yourself"}, status: :unprocessable_entity
      else
        user.destroy!
        head :no_content
      end
    end
  end
end
