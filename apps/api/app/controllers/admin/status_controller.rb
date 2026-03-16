module Admin
  class StatusController < BaseController
    def show
      render json: {
        service: "inboxed-api",
        version: "0.1.0",
        status: "ok",
        mode: "standalone",
        timestamp: Time.current.iso8601,
        environment: Rails.env,
        features: feature_flags,
        database: database_status,
        redis: redis_status
      }
    end

    private

    def database_status
      ActiveRecord::Base.connection.execute("SELECT 1")
      "connected"
    rescue => e
      "error: #{e.message}"
    end

    def feature_flags
      {
        mail: true,
        hooks: ENV.fetch("INBOXED_FEATURE_HOOKS", "true") == "true",
        forms: ENV.fetch("INBOXED_FEATURE_FORMS", "true") == "true",
        heartbeats: ENV.fetch("INBOXED_FEATURE_HEARTBEATS", "true") == "true",
        mcp: true
      }
    end

    def redis_status
      ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
      require "net/http"
      "configured"
    rescue => e
      "error: #{e.message}"
    end
  end
end
