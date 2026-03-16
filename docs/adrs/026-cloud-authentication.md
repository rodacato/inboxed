# ADR-026: Cloud Authentication — Session Cookies over JWTs

**Status:** accepted
**Date:** 2026-03-16
**Deciders:** Project owner
**Panel consulted:** Security Engineer, Full-Stack Engineer, API Design Architect

## Context

Standalone Inboxed uses a single static admin token (`INBOXED_ADMIN_TOKEN`) for dashboard access and per-project API keys for programmatic access. Cloud mode adds user registration and per-user scoping. We need an authentication mechanism for cloud users.

### Requirements

1. User registers with email + password (and optionally GitHub OAuth)
2. Email verification required before functional access
3. Session persists across browser tabs and refreshes
4. Logout invalidates the session
5. API keys remain per-project (unchanged) — cloud auth is for the dashboard only
6. Standalone mode is unaffected — admin token still works

### Options Considered

**A: JWT (stateless tokens in localStorage)**
- Pro: Stateless — no server-side session storage
- Pro: Works across subdomains trivially
- Con: Can't be revoked without a blacklist (adds state anyway)
- Con: XSS can steal tokens from localStorage
- Con: Token refresh complexity (rotation, expiry, silent refresh)
- Con: JWTs are almost always the wrong choice for server-rendered or SPA-with-same-origin-API setups

**B: Session cookies with Rails session store**
- Pro: HttpOnly + Secure + SameSite=Strict — immune to XSS token theft
- Pro: Server-side invalidation on logout (delete session)
- Pro: Rails has mature, battle-tested session infrastructure
- Pro: Works naturally with `has_secure_password`
- Con: Requires CSRF protection for non-GET requests
- Con: Cookie doesn't work for cross-origin API calls (but cloud API uses API keys, not sessions)

**C: Token in HttpOnly cookie (custom implementation)**
- Pro: Similar security to B
- Con: Reinvents what Rails sessions already do
- Con: More code, more attack surface

## Decision

**Option B** — Rails session cookies backed by the database (Solid Cache or ActiveRecord session store).

### Why Not JWTs?

The dashboard is an SPA that talks to the same-origin Rails API. Session cookies are simpler, more secure (HttpOnly prevents XSS theft), and revocable. JWTs add complexity (refresh tokens, blacklists) without any benefit in this architecture.

API keys (per-project, Bearer token) remain the mechanism for programmatic access, CI/CD, and MCP. Sessions are only for the dashboard.

### Implementation

#### Session Store

```ruby
# config/initializers/session_store.rb
if ENV["INBOXED_MODE"] == "cloud"
  Rails.application.config.session_store :active_record_store,
    key: "_inboxed_session",
    secure: Rails.env.production?,
    httponly: true,
    same_site: :strict,
    expire_after: 7.days
else
  # Standalone: no session store needed (admin token auth)
  Rails.application.config.session_store :disabled
end
```

#### User Model

```ruby
class UserRecord < ApplicationRecord
  self.table_name = "users"
  has_secure_password

  has_many :users_projects, foreign_key: :user_id
  has_many :projects, through: :users_projects, source: :project

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, on: :create

  scope :verified, -> { where.not(verified_at: nil) }
end
```

#### Authentication Flow

```
Register (POST /auth/register)
  → Create user (unverified)
  → Send verification email (via Inboxed itself — dogfooding)
  → Return 201 with { message: "Check your email" }

Verify (GET /auth/verify?token=...)
  → Validate token
  → Set verified_at
  → Create session
  → Redirect to dashboard

Login (POST /auth/sessions)
  → Validate email + password
  → Check verified_at is present
  → Create session (session[:user_id])
  → Return 200 with user data

Logout (DELETE /auth/sessions)
  → Destroy session
  → Return 204

GitHub OAuth (GET /auth/github → callback)
  → OAuth flow via omniauth-github
  → Find or create user by GitHub email
  → Auto-verified (GitHub verified the email)
  → Create session
  → Redirect to dashboard
```

#### Session Controller

```ruby
# app/controllers/auth/sessions_controller.rb
module Auth
  class SessionsController < ApplicationController
    def create
      user = UserRecord.find_by(email: params[:email])

      if user&.authenticate(params[:password])
        if user.verified_at.nil?
          render json: { error: "email_not_verified" }, status: :forbidden
        else
          session[:user_id] = user.id
          render json: { data: serialize_user(user) }
        end
      else
        render json: { error: "invalid_credentials" }, status: :unauthorized
      end
    end

    def destroy
      reset_session
      head :no_content
    end
  end
end
```

#### Dashboard Auth Abstraction

The auth store (spec 009) already supports `mode: 'admin' | 'user'`. In cloud mode:

```typescript
// authStore behavior in cloud mode
authStore.mode = 'user';
authStore.user = { id, email, verified: true };
authStore.canManageAllProjects = false;
authStore.projectIds = [user's project IDs];
```

The API client switches from Bearer token to cookie-based auth:
- Standalone: `Authorization: Bearer <admin_token>`
- Cloud: No Authorization header (session cookie sent automatically by browser)

#### CSRF Protection

Since cloud mode uses session cookies, CSRF protection is required:

```ruby
# Cloud mode adds CSRF token to responses
# Dashboard reads from meta tag or X-CSRF-Token header
protect_from_forgery with: :exception, if: -> { cloud_mode? && !api_request? }
```

The SPA includes the CSRF token in a meta tag rendered by the Rails layout, and the API client sends it as `X-CSRF-Token` header on non-GET requests.

### Mode-Conditional Behavior

```ruby
# app/controllers/concerns/cloud_mode.rb
module CloudMode
  extend ActiveSupport::Concern

  included do
    helper_method :cloud_mode?, :standalone_mode?
  end

  def cloud_mode?
    ENV["INBOXED_MODE"] == "cloud"
  end

  def standalone_mode?
    !cloud_mode?
  end

  def current_user
    return nil unless cloud_mode?
    @current_user ||= UserRecord.find_by(id: session[:user_id])
  end

  def require_authentication!
    if cloud_mode?
      head :unauthorized unless current_user&.verified_at
    else
      # Standalone: admin token auth (existing behavior)
      authenticate_admin_token!
    end
  end
end
```

## Consequences

### Easier

- **Battle-tested** — Rails session + `has_secure_password` is the most mature auth stack in Ruby
- **Secure by default** — HttpOnly cookies prevent XSS token theft, SameSite prevents CSRF
- **Revocable** — logout destroys the session server-side, no token invalidation complexity
- **Simple SPA integration** — cookies are automatic, no token management in JavaScript

### Harder

- **CSRF handling** — SPA needs to read and send CSRF tokens (one-time setup)
- **Cross-origin** — if dashboard and API ever split to different domains, cookies need adjustment (not planned)

### Mitigations

- CSRF token served in response header, API client sends it automatically
- Session expiry (7 days) limits window of exposure for stolen cookies
- `Secure` flag ensures cookies only sent over HTTPS in production
