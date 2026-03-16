# frozen_string_literal: true

require "ostruct"

module Inboxed
  module Services
    class ResetPassword
      def call(token:, password:)
        user = UserRecord.find_by(password_reset_token: token)

        return failure("Invalid or expired reset token") unless user
        return failure("Token expired") if user.password_reset_sent_at < 1.hour.ago
        return failure("Password must be at least 8 characters") if password.to_s.length < 8

        user.update!(
          password: password,
          password_reset_token: nil,
          password_reset_sent_at: nil
        )

        success
      end

      private

      def success = OpenStruct.new(success?: true, errors: [])

      def failure(msg) = OpenStruct.new(success?: false, errors: [msg])
    end
  end
end
