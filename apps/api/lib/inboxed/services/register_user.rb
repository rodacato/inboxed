# frozen_string_literal: true

require "ostruct"

module Inboxed
  module Services
    class RegisterUser
      class RegistrationClosed < StandardError; end
      class InvitationExpired < StandardError; end

      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(email:, password:, invitation_token: nil)
        @email = email.to_s.downcase.strip
        @password = password
        @invitation_token = invitation_token

        validate_registration_allowed!

        if @invitation_token.present?
          register_via_invitation
        else
          register_open
        end
      rescue ActiveRecord::RecordInvalid => e
        failure(e.message)
      end

      private

      def validate_registration_allowed!
        mode = ENV.fetch("REGISTRATION_MODE", "closed")
        return if @invitation_token.present?
        raise RegistrationClosed unless mode == "open"
      end

      def register_open
        user = create_user
        org = CreateOrganizationWithDefaults.new.call(name: "#{@email.split("@").first}'s workspace", user: user)
        send_verification(user)
        publish_event(user, org, "email")
        success(user)
      end

      def register_via_invitation
        invitation = InvitationRecord.pending.find_by!(token: @invitation_token)
        raise InvitationExpired if invitation.expired?

        user = create_user

        MembershipRecord.create!(
          user: user,
          organization: invitation.organization,
          role: invitation.role
        )

        invitation.update!(accepted_at: Time.current)

        @event_store.publish(
          stream: "organization-#{invitation.organization_id}",
          events: [
            Events::InvitationAccepted.new(
              data: {
                invitation_id: invitation.id,
                user_id: user.id,
                organization_id: invitation.organization_id
              }
            )
          ]
        )

        send_verification(user)
        publish_event(user, invitation.organization, "invitation")
        success(user)
      end

      def create_user
        auto_verify = !outbound_smtp_configured?
        UserRecord.create!(
          email: @email,
          password: @password,
          verified_at: auto_verify ? Time.current : nil,
          verification_token: auto_verify ? nil : SecureRandom.urlsafe_base64(32),
          verification_sent_at: auto_verify ? nil : Time.current
        )
      end

      def send_verification(user)
        SendVerificationEmail.new.call(user: user) if outbound_smtp_configured? && !user.verified?
      end

      def outbound_smtp_configured?
        ENV["OUTBOUND_SMTP_HOST"].present?
      end

      def publish_event(user, org, method)
        @event_store.publish(
          stream: "user-#{user.id}",
          events: [
            Events::UserRegistered.new(
              data: {
                user_id: user.id,
                email: user.email,
                organization_id: org.id,
                registration_method: method
              }
            )
          ]
        )
      end

      def success(user) = OpenStruct.new(success?: true, user: user, errors: [])

      def failure(msg) = OpenStruct.new(success?: false, user: nil, errors: [msg])
    end
  end
end
