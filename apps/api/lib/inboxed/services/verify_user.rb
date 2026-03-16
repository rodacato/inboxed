# frozen_string_literal: true

require "ostruct"

module Inboxed
  module Services
    class VerifyUser
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(token:)
        user = UserRecord.find_by(verification_token: token)

        return failure("Invalid or expired verification token") unless user
        return failure("Token expired") if user.verification_sent_at < 24.hours.ago

        user.update!(
          verified_at: Time.current,
          verification_token: nil
        )

        @event_store.publish(
          stream: "user-#{user.id}",
          events: [
            Events::UserVerified.new(
              data: {user_id: user.id, email: user.email}
            )
          ]
        )

        success(user)
      end

      private

      def success(user) = OpenStruct.new(success?: true, user: user, errors: [])

      def failure(msg) = OpenStruct.new(success?: false, user: nil, errors: [msg])
    end
  end
end
