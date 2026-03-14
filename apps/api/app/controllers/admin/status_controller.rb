module Admin
  class StatusController < BaseController
    def show
      render json: {
        service: "inboxed-api",
        version: "0.0.1",
        status: "ok",
        timestamp: Time.current.iso8601,
        environment: Rails.env,
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

    def redis_status
      redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
      require "net/http"
      "configured"
    rescue => e
      "error: #{e.message}"
    end
  end
end
