# frozen_string_literal: true

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
        user = create_user(verified: !outbound_smtp_configured?)

        trial_days = ENV.fetch("TRIAL_DURATION_DAYS", "7").to_i
        org = OrganizationRecord.create!(
          name: "#{@email.split("@").first}'s workspace",
          slug: SecureRandom.uuid.split("-").first,
          trial_ends_at: (trial_days > 0) ? trial_days.days.from_now : nil
        )

        MembershipRecord.create!(user: user, organization: org, role: "org_admin")
        create_default_project(org)

        SendVerificationEmail.new.call(user: user) if outbound_smtp_configured? && !user.verified?

        publish_event(user, org, "email")
        success(user)
      end

      def register_via_invitation
        invitation = InvitationRecord.pending.find_by!(token: @invitation_token)
        raise InvitationExpired if invitation.expired?

        user = create_user(verified: !outbound_smtp_configured?)

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

        SendVerificationEmail.new.call(user: user) if outbound_smtp_configured? && !user.verified?

        publish_event(user, invitation.organization, "invitation")
        success(user)
      end

      def create_user(verified: false)
        UserRecord.create!(
          email: @email,
          password: @password,
          verified_at: verified ? Time.current : nil,
          verification_token: verified ? nil : SecureRandom.urlsafe_base64(32),
          verification_sent_at: verified ? nil : Time.current
        )
      end

      def create_default_project(org)
        project = ProjectRecord.create!(
          name: "My Project",
          slug: SecureRandom.uuid.split("-").first,
          organization: org,
          default_ttl_hours: 24
        )

        IssueApiKey.new.call(project_id: project.id, label: "Default key")
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
