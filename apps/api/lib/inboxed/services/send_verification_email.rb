# frozen_string_literal: true

module Inboxed
  module Services
    class SendVerificationEmail
      def call(user:)
        return unless ENV["OUTBOUND_SMTP_HOST"].present?
        return if user.verification_sent_at && user.verification_sent_at > 5.minutes.ago

        user.update!(
          verification_token: SecureRandom.urlsafe_base64(32),
          verification_sent_at: Time.current
        )

        UserMailer.verification(user).deliver_later
      end
    end
  end
end
