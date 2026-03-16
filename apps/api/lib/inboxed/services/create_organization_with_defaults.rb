# frozen_string_literal: true

require "ostruct"

module Inboxed
  module Services
    class CreateOrganizationWithDefaults
      def call(name:, user:, role: "org_admin", trial_days: nil)
        trial_days = trial_days.nil? ? ENV.fetch("TRIAL_DURATION_DAYS", "7").to_i : trial_days

        org = OrganizationRecord.create!(
          name: name,
          slug: SecureRandom.uuid.split("-").first,
          trial_ends_at: (trial_days > 0) ? trial_days.days.from_now : nil
        )

        MembershipRecord.create!(user: user, organization: org, role: role)

        project = ProjectRecord.create!(
          name: "My Project",
          slug: SecureRandom.uuid.split("-").first,
          organization: org,
          default_ttl_hours: 24
        )

        api_key = IssueApiKey.new.call(project_id: project.id, label: "Default key")

        OpenStruct.new(organization: org, project: project, api_key: api_key)
      end
    end
  end
end
