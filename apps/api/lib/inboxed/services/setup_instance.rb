# frozen_string_literal: true

module Inboxed
  module Services
    class SetupInstance
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(email:, password:, org_name:)
        org = OrganizationRecord.create!(
          name: org_name,
          slug: org_name.parameterize.presence || SecureRandom.uuid.split("-").first,
          trial_ends_at: nil
        )

        user = UserRecord.create!(
          email: email.downcase.strip,
          password: password,
          site_admin: true,
          verified_at: Time.current
        )

        MembershipRecord.create!(
          user: user,
          organization: org,
          role: "org_admin"
        )

        Inboxed::Settings.set(:setup_completed_at, Time.current)

        @event_store.publish(
          stream: "user-#{user.id}",
          events: [
            Events::UserRegistered.new(
              data: {
                user_id: user.id,
                email: user.email,
                organization_id: org.id,
                registration_method: "setup"
              }
            )
          ]
        )

        OpenStruct.new(user: user, organization: org)
      end
    end
  end
end
