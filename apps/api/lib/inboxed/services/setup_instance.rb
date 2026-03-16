# frozen_string_literal: true

require "ostruct"

module Inboxed
  module Services
    class SetupInstance
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(email:, password:, org_name:)
        user = UserRecord.create!(
          email: email.downcase.strip,
          password: password,
          site_admin: true,
          verified_at: Time.current
        )

        org = CreateOrganizationWithDefaults.new.call(
          name: org_name,
          user: user,
          role: "org_admin",
          trial_days: 0
        )

        # Override slug with a readable one from the org name
        readable_slug = org_name.parameterize.presence || org.slug
        org.update!(slug: readable_slug) if readable_slug != org.slug

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
