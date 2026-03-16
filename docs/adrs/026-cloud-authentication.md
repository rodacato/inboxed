# ADR-026: Dashboard Authentication — Session Cookies with Setup Wizard

> **Updated 2026-03-16:** Rewritten to remove `INBOXED_MODE` dual-mode design. Inboxed is always multi-user. The admin token becomes a one-time setup token, replaced by session-based auth after first boot.

**Status:** accepted
**Date:** 2026-03-16
**Deciders:** Project owner
**Panel consulted:** Security Engineer, Full-Stack Engineer, API Design Architect, Product Manager

## Context

Inboxed needs dashboard authentication that works for all deployment scenarios: a solo developer on localhost, a team on a shared VPS, or a public instance open for registration. Rather than maintaining separate auth modes (`standalone` vs `cloud`), a unified model simplifies the codebase and avoids `if mode == ...` conditionals throughout.

### Requirements

1. First boot creates an admin account via a setup wizard (seeded from `INBOXED_SETUP_TOKEN`)
2. Users authenticate with email + password, or GitHub OAuth
3. Email verification required when outbound SMTP is configured
4. Sessions persist across browser tabs and refreshes
5. Logout invalidates the session server-side
6. API keys remain per-project, unchanged — sessions are for the dashboard only
7. No `INBOXED_MODE` flag — one auth model for all deployments

### Options Considered

**A: JWT (stateless tokens in localStorage)**
- Pro: Stateless — no server-side session storage
- Con: Can't be revoked without a blacklist (adds state anyway)
- Con: XSS can steal tokens from localStorage
- Con: Token refresh complexity (rotation, expiry, silent refresh)
- Con: JWTs are almost always the wrong choice for SPA-with-same-origin-API setups

**B: Session cookies with Rails session store**
- Pro: HttpOnly + Secure + SameSite=Strict — immune to XSS token theft
- Pro: Server-side invalidation on logout (delete session)
- Pro: Rails has mature, battle-tested session infrastructure
- Pro: Works naturally with `has_secure_password`
- Con: Requires CSRF protection for non-GET requests

**C: Keep dual-mode (`INBOXED_MODE` flag) with admin token for standalone**
- Pro: Simpler for solo users (no registration needed)
- Con: Every controller needs `if cloud_mode?` conditionals
- Con: Two auth paths to test and maintain
- Con: Static admin token is a security liability (never rotated, shared in env files)

## Decision

**Option B** — Rails session cookies for all deployments, with a one-time setup wizard to create the first admin account.

### Why Not Keep the Admin Token (Option C)?

A static admin token in an env var is a security anti-pattern for anything beyond local development. It can't be rotated without restarting the server, it's often committed to `.env` files, and it provides no audit trail. Replacing it with real user accounts from day one means:

- Session expiry and rotation happen automatically
- Each user has their own credentials (audit trail)
- The same auth code works for solo dev, team, and public instances
- No `if standalone?` / `if cloud?` branching

### Setup Flow (First Boot)

The `INBOXED_SETUP_TOKEN` env var is used exactly once — to create the first admin account:

```
1. Operator sets INBOXED_SETUP_TOKEN in env (or it's auto-generated on first run)
2. First visit to dashboard → redirected to /setup
3. /setup requires the setup token as proof of server access
4. Operator creates admin account (email + password)
5. Setup token is invalidated (setup_completed_at stored in settings)
6. All further auth is via user sessions
```

```ruby
# app/controllers/setup_controller.rb
class SetupController < ApplicationController
  before_action :ensure_setup_available

  def show
    # Render setup form
  end

  def create
    return head :forbidden unless valid_setup_token?

    user = Inboxed::Application::Services::CreateFirstAdmin.call(
      email: params[:email],
      password: params[:password],
      setup_token: params[:setup_token]
    )

    session[:user_id] = user.id
    Inboxed::Settings.set(:setup_completed_at, Time.current)

    redirect_to "/projects"
  end

  private

  def ensure_setup_available
    redirect_to "/login" if Inboxed::Settings.get(:setup_completed_at).present?
  end

  def valid_setup_token?
    expected = ENV["INBOXED_SETUP_TOKEN"]
    return false unless expected.present?
    ActiveSupport::SecurityUtils.secure_compare(params[:setup_token].to_s, expected)
  end
end
```

### Session Store

Always active — no conditional based on mode:

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :active_record_store,
  key: "_inboxed_session",
  secure: Rails.env.production?,
  httponly: true,
  same_site: :strict,
  expire_after: 7.days
```

### Authentication Flow

```
Setup (GET/POST /setup) — first boot only
  → Validate setup token
  → Create admin user (site_admin role, auto-verified)
  → Create session
  → Redirect to dashboard

Register (POST /auth/register) — when registration is enabled
  → Create user (unverified if SMTP configured, auto-verified if not)
  → Send verification email if SMTP configured
  → Return 201

Login (POST /auth/sessions)
  → Validate email + password
  → Check verified (if verification required)
  → Create session
  → Return 200 with user data

GitHub OAuth (GET /auth/github → callback)
  → OAuth flow
  → Find or create user (auto-verified)
  → Create session
  → Redirect to dashboard
```

### Graceful Degradation Without Outbound SMTP

If `OUTBOUND_SMTP_HOST` is not configured:
- Registration still works, but users are **auto-verified** (no email sent)
- Password reset is unavailable (admin can reset manually)
- The dashboard shows a notice: "Configure outbound SMTP for email verification and password reset"

This means a solo developer can run Inboxed without configuring an email relay — they just create their account via setup and use it. Teams that need registration configure SMTP.

### CSRF Protection

Always active for session-based requests:

```ruby
protect_from_forgery with: :exception, unless: -> { api_key_request? }
```

API key requests (Bearer token) skip CSRF — they don't use cookies.

### Dashboard Auth Store

```typescript
// authStore — unified, no mode switching
authStore.isAuthenticated = true;
authStore.user = { id, email, role, organizationId };
authStore.features = status.features;
// API client uses cookie auth (automatic) for dashboard
// API keys used separately for programmatic access
```

## Consequences

### Easier

- **One auth model** — no `if cloud_mode?` branching anywhere
- **Battle-tested** — Rails session + `has_secure_password`
- **Secure by default** — HttpOnly cookies, server-side revocation
- **Graceful degradation** — works without SMTP relay for solo use

### Harder

- **Setup wizard** — one-time first-boot flow (small, but new)
- **CSRF in SPA** — dashboard must send CSRF token on non-GET requests

### Mitigations

- Setup wizard is < 50 lines of controller code
- CSRF token served in response header, API client sends it automatically
- Session expiry (7 days) limits exposure window
