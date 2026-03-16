# frozen_string_literal: true

class Rack::Attack
  # Per API key: 300 requests per minute (5/sec sustained)
  throttle("api/key", limit: ENV.fetch("RATE_LIMIT_API", 300).to_i, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1/") && req.env["inboxed.api_key_id"]
      req.env["inboxed.api_key_id"]
    end
  end

  # Per IP for admin endpoints: 60 requests per minute
  throttle("admin/ip", limit: ENV.fetch("RATE_LIMIT_ADMIN", 60).to_i, period: 1.minute) do |req|
    if req.path.start_with?("/admin/")
      req.ip
    end
  end

  # Public catch endpoint — per token: 120 requests per minute
  throttle("hook/per_token", limit: ENV.fetch("RATE_LIMIT_HOOK", 120).to_i, period: 1.minute) do |req|
    if req.path.start_with?("/hook/")
      req.path.match(%r{^/hook/([^/]+)})&.captures&.first
    end
  end

  # Public catch endpoint — global: 1000 requests per minute
  throttle("hook/global", limit: ENV.fetch("RATE_LIMIT_HOOK_GLOBAL", 1000).to_i, period: 1.minute) do |req|
    "global" if req.path.start_with?("/hook/")
  end

  # Auth endpoint protection: 5 failed attempts per 5 minutes per IP
  throttle("auth/ip", limit: ENV.fetch("RATE_LIMIT_AUTH", 5).to_i, period: 5.minutes) do |req|
    if req.path.start_with?("/api/v1/") && req.env["inboxed.auth_failed"]
      req.ip
    end
  end

  self.throttled_responder = lambda do |env|
    match_data = env["rack.attack.match_data"] || {}
    limit = match_data[:limit] || 0
    period = match_data[:period] || 60
    retry_after = (period - (Time.current.to_i % period)).to_s

    [
      429,
      {
        "Content-Type" => "application/problem+json",
        "Retry-After" => retry_after,
        "X-RateLimit-Limit" => limit.to_s,
        "X-RateLimit-Remaining" => "0",
        "X-RateLimit-Reset" => (Time.current.to_i + retry_after.to_i).to_s
      },
      [{
        type: "https://docs.inboxed.dev/errors/rate-limited",
        title: "Rate limit exceeded",
        detail: "Rate limit exceeded. Retry after #{retry_after} seconds.",
        status: 429
      }.to_json]
    ]
  end
end
