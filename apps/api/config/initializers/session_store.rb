# frozen_string_literal: true

# Session cookies — always active for dashboard authentication.
# API key requests (Bearer token) skip session entirely.
Rails.application.config.middleware.use ActionDispatch::Cookies
Rails.application.config.middleware.use ActionDispatch::Session::CookieStore,
  key: "_inboxed_session",
  secure: Rails.env.production?,
  same_site: :lax,
  expire_after: 7.days,
  httponly: true

Rails.application.config.action_dispatch.cookies_same_site_protection = :lax
