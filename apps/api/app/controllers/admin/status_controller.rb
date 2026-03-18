# frozen_string_literal: true

module Admin
  class StatusController < BaseController
    skip_before_action :require_auth!

    def show
      response = {
        service: "inboxed-api",
        version: "0.2.0",
        status: "ok",
        setup_completed: Inboxed::Settings.setup_completed?,
        registration_mode: ENV.fetch("REGISTRATION_MODE", "closed"),
        outbound_smtp_configured: outbound_smtp_configured?,
        timestamp: Time.current.iso8601,
        environment: Rails.env,
        turnstile_site_key: ENV["TURNSTILE_SITE_KEY"],
        features: Inboxed::Features.all,
        smtp: {
          host: ENV.fetch("INBOXED_DOMAIN", "localhost"),
          port: ENV.fetch("INBOXED_SMTP_PORT", "2525").to_i
        },
        database: database_status,
        redis: redis_status
      }

      if current_user
        response[:user] = {
          id: current_user.id,
          email: current_user.email,
          role: current_user.role_in(current_user.organization),
          site_admin: current_user.site_admin?
        }

        org = current_user.organization
        if org
          response[:organization] = {
            id: org.id,
            name: org.name,
            slug: org.slug,
            trial: org.trial?,
            trial_ends_at: org.trial_ends_at&.iso8601
          }
        end
      end

      render json: response
    end

    private

    def database_status
      ActiveRecord::Base.connection.execute("SELECT 1")
      "connected"
    rescue => e
      "error: #{e.message}"
    end

    def redis_status
      ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
      "configured"
    rescue => e
      "error: #{e.message}"
    end
  end
end
