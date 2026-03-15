# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :admin_authenticated

    def connect
      self.admin_authenticated = authenticate_admin
    end

    private

    def authenticate_admin
      token = request.params[:token]
      admin_token = ENV["INBOXED_ADMIN_TOKEN"]

      reject_unauthorized_connection unless token.present? &&
        admin_token.present? &&
        ActiveSupport::SecurityUtils.secure_compare(token, admin_token)

      true
    end
  end
end
