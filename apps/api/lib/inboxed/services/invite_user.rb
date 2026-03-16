# frozen_string_literal: true

module Inboxed
  module Services
    class InviteUser
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(organization:, email:, role:, invited_by:)
        invitation = InvitationRecord.create!(
          organization: organization,
          email: email.downcase.strip,
          role: role,
          token: SecureRandom.urlsafe_base64(32),
          invited_by: invited_by,
          expires_at: 7.days.from_now
        )

        if ENV["OUTBOUND_SMTP_HOST"].present?
          InvitationMailer.invite(invitation).deliver_later
        end

        @event_store.publish(
          stream: "organization-#{organization.id}",
          events: [
            Events::UserInvited.new(
              data: {
                invitation_id: invitation.id,
                organization_id: organization.id,
                email: email,
                role: role,
                invited_by_id: invited_by.id
              }
            )
          ]
        )

        invitation
      end
    end
  end
end
