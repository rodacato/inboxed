# frozen_string_literal: true

module Inboxed
  module Services
    class SendPasswordReset
      def call(user:)
        return unless ENV["OUTBOUND_SMTP_HOST"].present?
        return if user.password_reset_sent_at && user.password_reset_sent_at > 5.minutes.ago

        user.update!(
          password_reset_token: SecureRandom.urlsafe_base64(32),
          password_reset_sent_at: Time.current
        )

        UserMailer.password_reset(user).deliver_later
      end
    end
  end
end
