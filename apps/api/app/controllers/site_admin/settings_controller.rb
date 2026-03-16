# frozen_string_literal: true

module SiteAdmin
  class SettingsController < BaseController
    def show
      render json: {
        data: {
          registration_mode: ENV.fetch("REGISTRATION_MODE", "closed"),
          trial_duration_days: ENV.fetch("TRIAL_DURATION_DAYS", "7").to_i,
          outbound_smtp_configured: ENV["OUTBOUND_SMTP_HOST"].present?,
          github_oauth_configured: ENV["GITHUB_CLIENT_ID"].present?,
          setup_completed_at: Inboxed::Settings.get(:setup_completed_at),
          user_count: UserRecord.count,
          organization_count: OrganizationRecord.count
        }
      }
    end
  end
end
