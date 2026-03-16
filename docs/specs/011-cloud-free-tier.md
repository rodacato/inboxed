# Spec 011 — Inboxed Cloud: Free Tier as Self-Hosted Funnel

> Add multi-tenant cloud mode to the same codebase. User registration, email verification, tenant-scoped data, free tier limits, and a conversion funnel to self-hosting. Same Rails app, same Docker image, different ENV flag.

**Phase:** 9
**Status:** accepted
**Created:** 2026-03-16
**Depends on:** [001 — Architecture](001-architecture.md), [002 — SMTP Persistence](002-smtp-persistence.md), [003 — REST API](003-rest-api.md), [004 — Dashboard](004-dashboard.md), [009 — Usability](009-usability.md) (auth abstraction, feature flags), [010 — HTTP Catcher](010-http-catcher.md)
**ADRs:** [022 — Cloud Free Tier](../adrs/022-cloud-free-tier.md), [026 — Cloud Authentication](../adrs/026-cloud-authentication.md), [027 — Tenant Isolation](../adrs/027-tenant-isolation.md), [028 — Cloud SMTP Routing](../adrs/028-cloud-smtp-routing.md)
**Expert panel:** Security Engineer, Full-Stack Engineer, API Design Architect, DevOps Engineer, Product Manager, UX/UI Designer

---

## 1. Objective

Turn Inboxed into a try-before-you-self-host product. A developer registers at `cloud.inboxed.dev`, gets a working inbox in 30 seconds, hits the free tier limits in a day of real work, and follows the CTA to `docker compose up` on their own machine.

**Core principle:** Cloud is a marketing cost (~€7-10/mo), not a revenue stream. Success = `docker pull` conversions, not cloud retention.

**What changes:**
- Same codebase, same Docker image — `INBOXED_MODE=cloud` activates multi-tenant behavior
- Users, registration, email verification, session auth
- Tenant-scoped data access (every query filtered by user's projects)
- Free tier limits with clear messaging and self-hosting CTAs
- Feature gates (no MCP, no HTML preview in cloud)
- Wildcard subdomain SMTP routing (`*@{slug}.inboxed.dev`)

**What doesn't change:**
- Standalone mode is the default and has zero multi-tenant code paths
- API key authentication for programmatic access
- All existing features work identically in standalone
- Same deploy pipeline, same Docker image

---

## 2. Current State

### What exists

- **Auth abstraction** (spec 009) — `authStore` supports `mode: 'admin' | 'user'`, feature flags via `/admin/status`
- **Feature flag system** — dashboard sidebar/tabs driven by `features` map from API
- **Admin token auth** — `INBOXED_ADMIN_TOKEN` for dashboard, per-project API keys for programmatic access
- **Project model** — `project_id` on every resource (inboxes, emails, endpoints, etc.)
- **TTL cleanup** — existing background jobs for email and HTTP request expiry
- **SMTP server** — `midi-smtp-server` with AUTH and domain routing
- **Rate limiting** — Rack::Attack configured for API and admin endpoints

### What this spec adds

- `users` and `users_projects` database tables
- `sessions` table for ActiveRecord session store
- Registration flow with email verification
- GitHub OAuth (optional, via omniauth)
- Session-based dashboard auth (cloud mode only)
- `CurrentTenant` context for row-level data scoping
- `CloudLimits` enforcement at service layer
- Wildcard subdomain SMTP routing
- Per-user SMTP rate limiting
- Limit banners in dashboard with self-hosting CTAs
- Feature gates (MCP disabled, HTML preview disabled)
- Tenant isolation test suite
- Cloud-specific configuration overlay for Docker

---

## 3. Data Model

### 3.1 New Tables

#### `users`

```sql
CREATE TABLE users (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email             VARCHAR NOT NULL,
  password_digest   VARCHAR NOT NULL,
  github_uid        VARCHAR,
  github_username   VARCHAR,
  verified_at       TIMESTAMPTZ,
  verification_token VARCHAR,
  verification_sent_at TIMESTAMPTZ,
  password_reset_token VARCHAR,
  password_reset_sent_at TIMESTAMPTZ,
  last_sign_in_at   TIMESTAMPTZ,
  sign_in_count     INTEGER DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT users_email_unique UNIQUE (email),
  CONSTRAINT users_github_uid_unique UNIQUE (github_uid)
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_verification_token ON users(verification_token)
  WHERE verification_token IS NOT NULL;
CREATE INDEX idx_users_password_reset_token ON users(password_reset_token)
  WHERE password_reset_token IS NOT NULL;
```

#### `users_projects`

```sql
CREATE TABLE users_projects (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  role        VARCHAR NOT NULL DEFAULT 'owner',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT users_projects_unique UNIQUE (user_id, project_id),
  CONSTRAINT users_projects_role_check CHECK (role IN ('owner', 'member'))
);

CREATE INDEX idx_users_projects_user ON users_projects(user_id);
CREATE INDEX idx_users_projects_project ON users_projects(project_id);
```

#### `sessions` (ActiveRecord session store)

```sql
CREATE TABLE sessions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id  VARCHAR NOT NULL,
  data        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT sessions_session_id_unique UNIQUE (session_id)
);

CREATE INDEX idx_sessions_session_id ON sessions(session_id);
CREATE INDEX idx_sessions_updated_at ON sessions(updated_at);
```

### 3.2 Domain Layer

#### Entity

```ruby
# app/domain/entities/user.rb
module Inboxed::Domain::Entities
  class User < Dry::Struct
    attribute :id, Types::UUID
    attribute :email, Types::String
    attribute :verified, Types::Bool
    attribute :github_uid, Types::String.optional
    attribute :github_username, Types::String.optional
    attribute :last_sign_in_at, Types::Time.optional
    attribute :sign_in_count, Types::Integer
    attribute :created_at, Types::Time

    def verified?
      verified
    end

    def github_linked?
      github_uid.present?
    end
  end
end
```

#### Events

```ruby
# app/domain/events/user_registered.rb
module Inboxed::Domain::Events
  class UserRegistered < Base
    attribute :user_id, Types::UUID
    attribute :email, Types::String
    attribute :registration_method, Types::String  # 'email' | 'github'
  end
end

# app/domain/events/user_verified.rb
module Inboxed::Domain::Events
  class UserVerified < Base
    attribute :user_id, Types::UUID
    attribute :email, Types::String
  end
end

# app/domain/events/user_signed_in.rb
module Inboxed::Domain::Events
  class UserSignedIn < Base
    attribute :user_id, Types::UUID
    attribute :email, Types::String
    attribute :method, Types::String  # 'password' | 'github'
  end
end
```

### 3.3 ActiveRecord Models

```ruby
# app/models/user_record.rb
class UserRecord < ApplicationRecord
  self.table_name = "users"
  has_secure_password

  has_many :users_projects, foreign_key: :user_id, dependent: :destroy
  has_many :projects, through: :users_projects, source: :project,
           class_name: "ProjectRecord"

  validates :email, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, on: :create

  scope :verified, -> { where.not(verified_at: nil) }
  scope :unverified, -> { where(verified_at: nil) }
end

# app/models/users_project_record.rb
class UsersProjectRecord < ApplicationRecord
  self.table_name = "users_projects"

  belongs_to :user, class_name: "UserRecord"
  belongs_to :project, class_name: "ProjectRecord"

  validates :role, inclusion: { in: %w[owner member] }
end
```

---

## 4. Authentication

See [ADR-026](../adrs/026-cloud-authentication.md) for the full design rationale.

### 4.1 Routes

```ruby
# config/routes.rb (additions — only active in cloud mode)
scope constraints: ->(req) { ENV["INBOXED_MODE"] == "cloud" } do
  namespace :auth do
    post   "register",         to: "registrations#create"
    get    "verify",           to: "verifications#show"
    post   "resend-verification", to: "verifications#create"
    post   "sessions",         to: "sessions#create"
    delete "sessions",         to: "sessions#destroy"
    get    "me",               to: "sessions#show"
    post   "forgot-password",  to: "passwords#create"
    put    "reset-password",   to: "passwords#update"

    # GitHub OAuth (optional)
    get    "github",           to: "oauth#github"
    get    "github/callback",  to: "oauth#github_callback"
  end
end
```

### 4.2 Controllers

#### Registration

```ruby
# app/controllers/auth/registrations_controller.rb
module Auth
  class RegistrationsController < ApplicationController
    def create
      result = Inboxed::Application::Services::RegisterUser.call(
        email: params[:email],
        password: params[:password]
      )

      if result.success?
        render json: {
          message: "Check your email to verify your account",
          email: params[:email]
        }, status: :created
      else
        render json: { errors: result.errors }, status: :unprocessable_entity
      end
    end
  end
end
```

#### Email Verification

```ruby
# app/controllers/auth/verifications_controller.rb
module Auth
  class VerificationsController < ApplicationController
    def show
      result = Inboxed::Application::Services::VerifyUser.call(
        token: params[:token]
      )

      if result.success?
        session[:user_id] = result.user.id
        redirect_to "/projects"
      else
        redirect_to "/login?error=invalid_verification"
      end
    end

    def create
      user = UserRecord.find_by(email: params[:email])
      if user && user.verified_at.nil?
        Inboxed::Application::Services::SendVerificationEmail.call(user: user)
      end
      # Always return success to prevent email enumeration
      render json: { message: "If that email exists, we sent a verification link" }
    end
  end
end
```

#### Sessions

```ruby
# app/controllers/auth/sessions_controller.rb
module Auth
  class SessionsController < ApplicationController
    def create
      result = Inboxed::Application::Services::AuthenticateUser.call(
        email: params[:email],
        password: params[:password]
      )

      case result
      in { status: :success, user: }
        session[:user_id] = user.id
        user.update!(last_sign_in_at: Time.current, sign_in_count: user.sign_in_count + 1)
        render json: { data: serialize_user(user) }
      in { status: :unverified }
        render json: { error: "email_not_verified", message: "Please verify your email first" }, status: :forbidden
      in { status: :invalid }
        render json: { error: "invalid_credentials" }, status: :unauthorized
      end
    end

    def show
      if current_user
        render json: { data: serialize_user(current_user) }
      else
        head :unauthorized
      end
    end

    def destroy
      reset_session
      head :no_content
    end
  end
end
```

### 4.3 Application Services

```ruby
# app/application/services/register_user.rb
module Inboxed::Application::Services
  class RegisterUser
    def self.call(email:, password:)
      new(email:, password:).call
    end

    def initialize(email:, password:)
      @email = email.downcase.strip
      @password = password
    end

    def call
      return failure("Email already registered") if UserRecord.exists?(email: @email)
      return failure("Password must be at least 8 characters") if @password.length < 8

      user = UserRecord.create!(
        email: @email,
        password: @password,
        verification_token: SecureRandom.urlsafe_base64(32),
        verification_sent_at: Time.current
      )

      # Auto-create project with UUID slug
      project = create_default_project(user)

      # Send verification email
      SendVerificationEmail.call(user: user)

      # Publish event
      publish_event(user)

      success(user)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.message)
    end

    private

    def create_default_project(user)
      slug = SecureRandom.uuid.split("-").first  # e.g., "a7f3b2c1"
      project = ProjectRecord.create!(
        name: "My Project",
        slug: slug,
        default_ttl_hours: 1  # Cloud TTL: 1 hour, non-negotiable
      )

      UsersProjectRecord.create!(
        user: user,
        project: project,
        role: "owner"
      )

      # Auto-create first API key
      Inboxed::Services::IssueApiKey.call(
        project_id: project.id,
        label: "Default key"
      )

      project
    end

    def publish_event(user)
      Inboxed::Infrastructure::EventStore::Bus.publish(
        Inboxed::Domain::Events::UserRegistered.new(
          user_id: user.id,
          email: user.email,
          registration_method: "email"
        ),
        stream: "user-#{user.id}"
      )
    end

    def success(user) = OpenStruct.new(success?: true, user: user, errors: [])
    def failure(msg)   = OpenStruct.new(success?: false, user: nil, errors: [msg])
  end
end
```

```ruby
# app/application/services/verify_user.rb
module Inboxed::Application::Services
  class VerifyUser
    def self.call(token:)
      new(token:).call
    end

    def initialize(token:)
      @token = token
    end

    def call
      user = UserRecord.find_by(verification_token: @token)

      return failure("Invalid or expired verification token") unless user
      return failure("Token expired") if user.verification_sent_at < 24.hours.ago

      user.update!(
        verified_at: Time.current,
        verification_token: nil
      )

      publish_event(user)
      success(user)
    end

    private

    def publish_event(user)
      Inboxed::Infrastructure::EventStore::Bus.publish(
        Inboxed::Domain::Events::UserVerified.new(
          user_id: user.id,
          email: user.email
        ),
        stream: "user-#{user.id}"
      )
    end

    def success(user) = OpenStruct.new(success?: true, user: user, errors: [])
    def failure(msg)   = OpenStruct.new(success?: false, user: nil, errors: [msg])
  end
end
```

```ruby
# app/application/services/send_verification_email.rb
module Inboxed::Application::Services
  class SendVerificationEmail
    def self.call(user:)
      # Rate limit: max 3 verification emails per hour
      return if user.verification_sent_at && user.verification_sent_at > 5.minutes.ago

      user.update!(
        verification_token: SecureRandom.urlsafe_base64(32),
        verification_sent_at: Time.current
      )

      UserMailer.verification(user).deliver_later
    end
  end
end
```

### 4.4 GitHub OAuth (Optional)

```ruby
# app/controllers/auth/oauth_controller.rb
module Auth
  class OauthController < ApplicationController
    def github
      redirect_to github_authorize_url, allow_other_host: true
    end

    def github_callback
      github_user = exchange_code_for_user(params[:code])
      return redirect_to "/login?error=github_failed" unless github_user

      user = find_or_create_github_user(github_user)
      session[:user_id] = user.id
      user.update!(last_sign_in_at: Time.current, sign_in_count: user.sign_in_count + 1)

      redirect_to "/projects"
    end

    private

    def find_or_create_github_user(gh)
      user = UserRecord.find_by(github_uid: gh[:id].to_s)
      return user if user

      user = UserRecord.find_by(email: gh[:email])
      if user
        user.update!(github_uid: gh[:id].to_s, github_username: gh[:login])
        return user
      end

      user = UserRecord.create!(
        email: gh[:email],
        password: SecureRandom.hex(32),  # Random password (login via GitHub only)
        github_uid: gh[:id].to_s,
        github_username: gh[:login],
        verified_at: Time.current  # GitHub verified the email
      )

      RegisterUser.new(email: "", password: "").send(:create_default_project, user)
      user
    end
  end
end
```

---

## 5. Tenant Isolation

See [ADR-027](../adrs/027-tenant-isolation.md) for the full design rationale.

### 5.1 CurrentTenant Context

```ruby
# lib/inboxed/current_tenant.rb
module Inboxed
  class CurrentTenant
    thread_mattr_accessor :user_id, :project_ids

    def self.set(user:)
      self.user_id = user.id
      self.project_ids = user.projects.pluck(:id)
      yield
    ensure
      self.user_id = nil
      self.project_ids = nil
    end

    def self.scope(relation)
      if set?
        relation.where(project_id: project_ids)
      else
        relation  # Standalone mode: no scoping
      end
    end

    def self.set?
      project_ids.present?
    end

    def self.owns_project?(project_id)
      return true unless set?  # Standalone: all projects accessible
      project_ids.include?(project_id)
    end
  end
end
```

### 5.2 CloudMode Concern

```ruby
# app/controllers/concerns/cloud_mode.rb
module CloudMode
  extend ActiveSupport::Concern

  included do
    before_action :set_tenant_context, if: :cloud_mode?
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

  private

  def set_tenant_context
    return unless current_user
    Inboxed::CurrentTenant.set(user: current_user) { yield }
  end

  def require_cloud_auth!
    return unless cloud_mode?
    head :unauthorized unless current_user&.verified_at
  end
end
```

### 5.3 Admin Controller Updates

The admin base controller switches behavior based on mode:

```ruby
# app/controllers/admin/base_controller.rb (updated)
module Admin
  class BaseController < ApplicationController
    include CloudMode

    before_action :authenticate!

    private

    def authenticate!
      if cloud_mode?
        require_cloud_auth!
      else
        authenticate_admin_token!  # Existing behavior
      end
    end

    # Existing admin token auth (unchanged)
    def authenticate_admin_token!
      token = request.headers["Authorization"]&.delete_prefix("Bearer ")
      expected = ENV.fetch("INBOXED_ADMIN_TOKEN")

      unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)
        head :unauthorized
      end
    end
  end
end
```

### 5.4 Scoped Queries

Every read model and repository that queries by `project_id` applies `CurrentTenant.scope` in cloud mode:

```ruby
# Example pattern applied to all existing read models:

# app/read_models/inboxed/read_models/inbox_list.rb (updated)
module Inboxed::ReadModels
  class InboxList
    def self.call(project_id:, **params)
      # Verify user owns this project in cloud mode
      unless Inboxed::CurrentTenant.owns_project?(project_id)
        raise ActiveRecord::RecordNotFound
      end

      scope = InboxRecord.where(project_id: project_id)
      # ... existing query logic
    end
  end
end
```

The project list itself is scoped:

```ruby
# app/read_models/inboxed/read_models/project_list.rb
module Inboxed::ReadModels
  class ProjectList
    def self.call(**params)
      scope = Inboxed::CurrentTenant.scope(ProjectRecord.all)
      scope.order(created_at: :desc)
    end
  end
end
```

---

## 6. Free Tier Limits

### 6.1 Limit Definitions

```ruby
# lib/inboxed/cloud_limits.rb
module Inboxed
  class CloudLimits
    LIMITS = {
      projects_per_user: 1,
      inboxes_per_project: 5,
      emails_per_project: 50,
      http_endpoints_per_project: 6,  # 2 webhook + 2 form + 2 heartbeat
      requests_per_endpoint: 20,
      api_keys_per_project: 2,
      ttl_hours: 1,
      api_rate_limit_per_minute: 60,
      smtp_rate_limit_per_hour: 10,
      max_email_body_bytes: 100_000,
      max_webhook_body_bytes: 262_144
    }.freeze

    def self.enforced?
      ENV["INBOXED_MODE"] == "cloud"
    end

    def self.check!(resource, user: nil, project: nil)
      return unless enforced?

      limit_info = evaluate(resource, user:, project:)
      return unless limit_info

      if limit_info[:current] >= limit_info[:limit]
        raise LimitExceeded.new(
          resource: resource,
          current: limit_info[:current],
          limit: limit_info[:limit]
        )
      end
    end

    def self.usage(user:, project:)
      return nil unless enforced?

      {
        projects: { current: user.projects.count, limit: LIMITS[:projects_per_user] },
        inboxes: { current: project.inboxes.count, limit: LIMITS[:inboxes_per_project] },
        emails: { current: project.emails.count, limit: LIMITS[:emails_per_project] },
        endpoints: { current: project.http_endpoints.count, limit: LIMITS[:http_endpoints_per_project] },
        api_keys: { current: project.api_keys.count, limit: LIMITS[:api_keys_per_project] }
      }
    end

    private

    def self.evaluate(resource, user:, project:)
      case resource
      when :project
        { current: user.projects.count, limit: LIMITS[:projects_per_user] }
      when :inbox
        { current: project.inboxes.count, limit: LIMITS[:inboxes_per_project] }
      when :email
        { current: project.emails.count, limit: LIMITS[:emails_per_project] }
      when :http_endpoint
        { current: project.http_endpoints.count, limit: LIMITS[:http_endpoints_per_project] }
      when :api_key
        { current: project.api_keys.count, limit: LIMITS[:api_keys_per_project] }
      end
    end
  end

  class LimitExceeded < StandardError
    attr_reader :resource, :current, :limit

    def initialize(resource:, current:, limit:)
      @resource = resource
      @current = current
      @limit = limit
      super(
        "Free tier limit reached: #{resource} (#{current}/#{limit}). " \
        "Self-host Inboxed for unlimited everything: https://github.com/your/inboxed"
      )
    end
  end
end
```

### 6.2 Limit Enforcement Points

| Resource | Enforcement point | Service |
|---|---|---|
| Projects | Project creation | `RegisterUser`, `CreateProject` |
| Inboxes | Inbox creation + SMTP auto-create | `CreateInbox`, SMTP handler |
| Emails | SMTP reception | SMTP handler, `PersistEmail` |
| HTTP endpoints | Endpoint creation | `CreateHttpEndpoint` |
| Requests per endpoint | Request capture | `CaptureHttpRequest` |
| API keys | Key generation | `IssueApiKey` |
| Email body size | SMTP reception | SMTP handler |
| Webhook body size | Catch endpoint | `HooksController` |
| API rate | Per-request | Rack::Attack |
| SMTP rate | Per-email | SMTP handler |

### 6.3 API Error Response

```json
{
  "error": {
    "type": "limit_exceeded",
    "resource": "inboxes",
    "current": 5,
    "limit": 5,
    "message": "Free tier limit reached: inboxes (5/5). Self-host Inboxed for unlimited everything.",
    "self_host_url": "https://github.com/your/inboxed",
    "docs_url": "https://inboxed.dev/docs/self-hosting"
  }
}
```

HTTP status: `429 Too Many Requests` with `Retry-After: 0` (not a rate limit — permanent until self-hosted).

### 6.4 Cloud Rate Limiting

```ruby
# config/initializers/rack_attack.rb (additions for cloud)
if ENV["INBOXED_MODE"] == "cloud"
  # Cloud API: 60 req/min per session (stricter than standalone's 300)
  Rack::Attack.throttle("cloud/api", limit: 60, period: 60) do |req|
    if req.path.start_with?("/admin/", "/api/v1/")
      req.session[:user_id] || req.ip
    end
  end
end
```

---

## 7. Feature Gates

### 7.1 Disabled Features in Cloud Mode

| Feature | Why disabled | How disabled |
|---|---|---|
| **MCP server** | Key differentiator for self-hosted. Strongest conversion driver. | MCP Docker service not started in cloud compose. API returns `mcp: false` in features. |
| **HTML email preview** | Cross-tenant XSS risk. Sandboxed iframe could still leak data via postMessage. | Dashboard shows text + headers only. `html_preview` feature flag = false. |
| **Custom TTL** | Cloud TTL is 1 hour, non-configurable. Prevents storage abuse. | Project `default_ttl_hours` locked to 1. UI hides TTL setting. |
| **Webhook relay/forward** | Abuse potential — cloud becomes an open HTTP proxy. | Feature not available. UI hidden. |

### 7.2 Status Endpoint Response (Cloud)

```json
{
  "status": "ok",
  "version": "1.2.0",
  "mode": "cloud",
  "features": {
    "mail": true,
    "hooks": true,
    "forms": true,
    "heartbeats": true,
    "mcp": false,
    "html_preview": false,
    "custom_ttl": false
  },
  "user": {
    "id": "...",
    "email": "dev@example.com",
    "verified": true
  },
  "limits": {
    "projects": { "current": 1, "limit": 1 },
    "inboxes": { "current": 3, "limit": 5 },
    "emails": { "current": 12, "limit": 50 },
    "endpoints": { "current": 1, "limit": 6 },
    "api_keys": { "current": 1, "limit": 2 }
  }
}
```

### 7.3 Feature Flag Implementation

```ruby
# lib/inboxed/features.rb
module Inboxed
  class Features
    def self.enabled?(feature)
      return true unless cloud_mode?

      CLOUD_FEATURES.fetch(feature.to_sym, false)
    end

    def self.all
      if cloud_mode?
        CLOUD_FEATURES
      else
        STANDALONE_FEATURES
      end
    end

    private

    STANDALONE_FEATURES = {
      mail: true, hooks: true, forms: true, heartbeats: true,
      mcp: true, html_preview: true, custom_ttl: true
    }.freeze

    CLOUD_FEATURES = {
      mail: true, hooks: true, forms: true, heartbeats: true,
      mcp: false, html_preview: false, custom_ttl: false
    }.freeze

    def self.cloud_mode?
      ENV["INBOXED_MODE"] == "cloud"
    end
  end
end
```

---

## 8. SMTP Multi-Tenant Routing

See [ADR-028](../adrs/028-cloud-smtp-routing.md) for the full design rationale.

### 8.1 Wildcard Subdomain Routing

```ruby
# In SMTP server mail handler (updated for cloud)
def route_recipient(recipient_address)
  local_part, domain = recipient_address.split("@", 2)

  if cloud_mode? && domain&.end_with?(".inboxed.dev")
    route_cloud(local_part, domain)
  else
    route_standalone(local_part, domain)  # Existing behavior
  end
end

def route_cloud(local_part, domain)
  slug = domain.sub(".inboxed.dev", "")

  # Reject system subdomain
  return reject("550 5.1.1 Reserved address") if slug == "system"

  project = ProjectRecord.find_by(slug: slug)
  return reject("550 5.1.1 Unknown project") unless project

  # Rate limit
  return reject("450 4.7.1 Rate limit exceeded") if smtp_rate_exceeded?(project)

  # Email count limit
  return reject("452 4.2.2 Mailbox full") if email_limit_exceeded?(project)

  # Find or create inbox (auto-create up to limit)
  address = "#{local_part}@#{domain}"
  inbox = find_or_create_inbox(project, address)
  return reject("452 4.2.2 Inbox limit reached") unless inbox

  accept(inbox)
end

def smtp_rate_exceeded?(project)
  return false unless cloud_mode?
  project.emails.where("received_at > ?", 1.hour.ago).count >= 10
end

def email_limit_exceeded?(project)
  return false unless cloud_mode?
  project.emails.count >= 50
end

def find_or_create_inbox(project, address)
  inbox = InboxRecord.find_by(address: address)
  return inbox if inbox

  return nil if project.inboxes.count >= Inboxed::CloudLimits::LIMITS[:inboxes_per_project]

  InboxRecord.create!(
    project: project,
    address: address,
    email_count: 0
  )
rescue ActiveRecord::RecordNotUnique
  InboxRecord.find_by(address: address)
end
```

### 8.2 DNS Configuration

Already covered in deploy documentation. For cloud:

```
MX    inboxed.dev          → mail.inboxed.dev  (priority 10)
MX    *.inboxed.dev        → mail.inboxed.dev  (priority 10)
A     mail.inboxed.dev     → <VPS IP>
A     cloud.inboxed.dev    → <VPS IP>
```

### 8.3 Abuse Prevention

| Vector | Mitigation |
|---|---|
| Spam relay | Registration requires email verification. Unverified accounts can't receive email. |
| SMTP flood | 10 emails/hour per project. `fail2ban` on SMTP port. Connection rate limit in midi-smtp-server. |
| Storage abuse | 1-hour TTL, 100KB email body cap, cleanup every 5 minutes |
| Account farming | Rate limit registration: 3 accounts per IP per hour |
| Enumeration | Slugs are 8-character hex UUIDs — 4 billion possible values |

---

## 9. Dashboard Changes

### 9.1 New Routes (Cloud Only)

```
src/routes/
├── register/+page.svelte          → registration form
├── verify/+page.svelte            → email verification landing
├── forgot-password/+page.svelte   → password reset request
├── reset-password/+page.svelte    → password reset form
└── login/+page.svelte             → updated: email/password + GitHub OAuth
```

### 9.2 Login Page (Cloud Mode)

```
┌──────────────────────────────────────────────────┐
│                                                    │
│              [@] inboxed                           │
│              The dev inbox                         │
│                                                    │
│  ┌──────────────────────────────────────────────┐  │
│  │  Email                                        │  │
│  │  ┌──────────────────────────────────────────┐ │  │
│  │  │ dev@example.com                           │ │  │
│  │  └──────────────────────────────────────────┘ │  │
│  │  Password                                     │  │
│  │  ┌──────────────────────────────────────────┐ │  │
│  │  │ ••••••••••                                │ │  │
│  │  └──────────────────────────────────────────┘ │  │
│  │                                                │  │
│  │  [        Sign in        ]                    │  │
│  │                                                │  │
│  │  ───────── or ─────────                       │  │
│  │                                                │  │
│  │  [  🐙  Continue with GitHub  ]               │  │
│  │                                                │  │
│  │  Don't have an account? Register              │  │
│  │  Forgot your password?                        │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  💡 Want unlimited everything?                     │
│     Self-host with docker compose up               │
│                                                    │
└──────────────────────────────────────────────────┘
```

### 9.3 Registration Page

```
┌──────────────────────────────────────────────────┐
│              [@] inboxed                           │
│              Try free. Self-host forever.           │
│                                                    │
│  ┌──────────────────────────────────────────────┐  │
│  │  Email                                        │  │
│  │  ┌──────────────────────────────────────────┐ │  │
│  │  │                                           │ │  │
│  │  └──────────────────────────────────────────┘ │  │
│  │  Password (min 8 characters)                  │  │
│  │  ┌──────────────────────────────────────────┐ │  │
│  │  │                                           │ │  │
│  │  └──────────────────────────────────────────┘ │  │
│  │                                                │  │
│  │  [      Create account      ]                 │  │
│  │                                                │  │
│  │  ───────── or ─────────                       │  │
│  │                                                │  │
│  │  [  🐙  Sign up with GitHub  ]                │  │
│  │                                                │  │
│  │  Already have an account? Sign in             │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  Free tier: 1 project • 5 inboxes • 50 emails     │
│  • 1h retention • No MCP                           │
│                                                    │
└──────────────────────────────────────────────────┘
```

### 9.4 Limit Banners

When a user approaches or hits a limit, banners appear in the dashboard:

```
┌─ ⚠ Free tier: 4/5 inboxes used ──────────────────────────────────────────┐
│  Self-host Inboxed for unlimited inboxes, MCP, and more.                   │
│  [📖 Self-hosting guide]  [🐳 docker compose up]                          │
└───────────────────────────────────────────────────────────────────────────┘
```

```
┌─ 🚫 Inbox limit reached (5/5) ───────────────────────────────────────────┐
│  You've reached the free tier inbox limit. Self-host for unlimited:        │
│  docker compose up                                              [Copy]     │
│  [📖 Full setup guide →]                                                   │
└───────────────────────────────────────────────────────────────────────────┘
```

#### Implementation

```svelte
<!-- $lib/components/LimitBanner.svelte -->
<script lang="ts">
  interface Props {
    resource: string;
    current: number;
    limit: number;
    threshold?: number;  // Show warning at this % (default: 80%)
  }

  let { resource, current, limit, threshold = 0.8 }: Props = $props();

  const ratio = $derived(current / limit);
  const isWarning = $derived(ratio >= threshold && ratio < 1);
  const isExceeded = $derived(ratio >= 1);
  const show = $derived(isWarning || isExceeded);
</script>

{#if show}
  <div class="border rounded-lg p-3 mb-4 font-mono text-sm
              {isExceeded ? 'border-error bg-error/10 text-error' : 'border-amber bg-amber/10 text-amber'}">
    <div class="flex items-center justify-between">
      <span>
        {isExceeded ? '🚫' : '⚠'}
        {resource}: {current}/{limit}
        {isExceeded ? '— limit reached' : '— approaching limit'}
      </span>
      <a href="https://github.com/your/inboxed" target="_blank"
         class="text-phosphor hover:underline text-xs">
        Self-host for unlimited →
      </a>
    </div>
  </div>
{/if}
```

### 9.5 Dashboard Auth Flow (Cloud vs Standalone)

```typescript
// src/lib/stores/auth.store.svelte.ts (updated)

// On app load:
async function initialize() {
  const status = await fetchStatus();

  if (status.mode === 'cloud') {
    // Cloud: check session
    const me = await fetchMe();
    if (me) {
      authStore.isAuthenticated = true;
      authStore.mode = 'user';
      authStore.user = me;
      authStore.features = status.features;
      authStore.limits = status.limits;
    } else {
      // Redirect to /login (cloud login page)
      goto('/login');
    }
  } else {
    // Standalone: existing admin token flow
    const token = localStorage.getItem('inboxed_admin_token');
    if (token) {
      authStore.isAuthenticated = true;
      authStore.mode = 'admin';
      authStore.token = token;
      authStore.features = status.features;
    } else {
      goto('/login');
    }
  }
}
```

### 9.6 Sidebar Updates (Cloud Mode)

```
┌─────────────────────────────────┐
│  [@] inboxed cloud              │
│─────────────────────────────────│
│  🔍 Search                      │
│                                 │
│  PROJECT: My Project       [⚙]  │
│    📧 Mail        (12/50)  ← usage shown │
│    🔗 Hooks In     (1/6)       │
│    📋 Forms        (0/6)       │
│    💓 Heartbeats   (0/6)       │
│                                 │
│  ⚠ Free tier                   │
│  1h retention • No MCP          │
│  [Self-host for unlimited →]    │
│─────────────────────────────────│
│  [🌙]  [● Connected]           │
│  dev@example.com  [Logout]      │
└─────────────────────────────────┘
```

Key differences from standalone:
- "inboxed cloud" label
- Usage counts show `current/limit`
- Free tier reminder in sidebar footer
- User email instead of "Admin" label
- No "New Project" button (cloud: 1 project max)

### 9.7 Project Settings (Cloud Mode)

The project settings page in cloud mode:
- **Name:** Editable
- **Slug:** Read-only (auto-generated UUID)
- **Email domain:** `*.{slug}.inboxed.dev` — prominent display with copy button
- **TTL:** "1 hour (cloud limit)" — not editable, with CTA to self-host
- **API keys:** Show/create (up to limit)
- **SMTP config:** Pre-filled with cloud server details

```
┌─ SMTP Configuration ──────────────────────────────────────────────────┐
│  Point your app's SMTP at Inboxed Cloud:                               │
│                                                                        │
│  ┌──────────────────────────────────────────────┐                      │
│  │ SMTP_HOST=mail.inboxed.dev                    │             [Copy]  │
│  │ SMTP_PORT=587                                 │                     │
│  │ SMTP_USER=inx_abc1...                         │                     │
│  │ SMTP_PASS=<your-api-key>                      │                     │
│  └──────────────────────────────────────────────┘                      │
│                                                                        │
│  Or send directly to: anything@a7f3b2c1.inboxed.dev                    │
└───────────────────────────────────────────────────────────────────────┘
```

---

## 10. Email Verification (Dogfooding)

Inboxed Cloud sends verification and password reset emails. This is an opportunity to dogfood the product.

### 10.1 ActionMailer Configuration

```ruby
# config/environments/production.rb (cloud additions)
if ENV["INBOXED_MODE"] == "cloud"
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("OUTBOUND_SMTP_HOST", "localhost"),
    port: ENV.fetch("OUTBOUND_SMTP_PORT", 587),
    user_name: ENV.fetch("OUTBOUND_SMTP_USER", nil),
    password: ENV.fetch("OUTBOUND_SMTP_PASS", nil),
    authentication: :plain,
    enable_starttls: true
  }
  config.action_mailer.default_url_options = {
    host: "cloud.inboxed.dev",
    protocol: "https"
  }
end
```

### 10.2 Mailer

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  default from: "Inboxed <noreply@inboxed.dev>"

  def verification(user)
    @user = user
    @url = "https://cloud.inboxed.dev/auth/verify?token=#{user.verification_token}"
    mail(to: user.email, subject: "Verify your Inboxed account")
  end

  def password_reset(user)
    @user = user
    @url = "https://cloud.inboxed.dev/reset-password?token=#{user.password_reset_token}"
    mail(to: user.email, subject: "Reset your Inboxed password")
  end
end
```

### 10.3 Email Templates

Plain text, minimal, developer-friendly:

```
Subject: Verify your Inboxed account

Hey,

Click here to verify your Inboxed account:

<%= @url %>

This link expires in 24 hours.

If you didn't create an account, ignore this email.

—
Inboxed — The dev inbox
https://inboxed.dev
```

---

## 11. Docker Configuration (Cloud)

### 11.1 Cloud Compose Overlay

```yaml
# docker-compose.cloud.yml (extends base docker-compose.yml)
services:
  api:
    environment:
      INBOXED_MODE: cloud
      INBOXED_ADMIN_TOKEN: ""  # Disabled in cloud
      OUTBOUND_SMTP_HOST: ${OUTBOUND_SMTP_HOST}
      OUTBOUND_SMTP_USER: ${OUTBOUND_SMTP_USER}
      OUTBOUND_SMTP_PASS: ${OUTBOUND_SMTP_PASS}
      GITHUB_CLIENT_ID: ${GITHUB_CLIENT_ID:-}
      GITHUB_CLIENT_SECRET: ${GITHUB_CLIENT_SECRET:-}

  # MCP server not started in cloud mode
  mcp:
    deploy:
      replicas: 0
```

Deploy command:
```bash
docker compose -f docker-compose.yml -f docker-compose.cloud.yml up -d
```

### 11.2 Cloud Environment Variables

```bash
# .env.cloud.example
INBOXED_MODE=cloud

# Outbound email (for verification/password reset)
OUTBOUND_SMTP_HOST=smtp.provider.com
OUTBOUND_SMTP_PORT=587
OUTBOUND_SMTP_USER=apikey
OUTBOUND_SMTP_PASS=your-key

# GitHub OAuth (optional)
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=

# Session secret (generate with: openssl rand -hex 64)
SECRET_KEY_BASE=

# Database (same as standalone)
DATABASE_URL=postgres://...
```

---

## 12. Cleanup & Maintenance

### 12.1 Aggressive Cleanup (Cloud)

Cloud mode uses more aggressive cleanup than standalone:

```ruby
# app/application/jobs/cloud_cleanup_job.rb
class CloudCleanupJob < ApplicationJob
  queue_as :default

  def perform
    return unless ENV["INBOXED_MODE"] == "cloud"

    # 1. Delete expired emails (TTL: 1 hour)
    emails_deleted = EmailRecord
      .where("expires_at < ?", Time.current)
      .delete_all

    # 2. Delete expired HTTP requests (TTL: 1 hour)
    requests_deleted = HttpRequestRecord
      .where("expires_at < ?", Time.current)
      .delete_all

    # 3. Delete unverified accounts older than 24 hours
    users_deleted = UserRecord
      .unverified
      .where("created_at < ?", 24.hours.ago)
      .destroy_all
      .count

    # 4. Clean expired sessions
    sessions_deleted = Session
      .where("updated_at < ?", 7.days.ago)
      .delete_all

    Rails.logger.info(
      "CloudCleanup: emails=#{emails_deleted} requests=#{requests_deleted} " \
      "users=#{users_deleted} sessions=#{sessions_deleted}"
    )
  end
end
```

```yaml
# config/recurring.yml (additions)
cloud_cleanup:
  class: CloudCleanupJob
  schedule: every 5 minutes
```

### 12.2 Session Cleanup

Sessions auto-expire after 7 days (configured in session store). The cleanup job removes stale sessions from the database.

---

## 13. Technical Decisions

### 13.1 Session Cookies vs JWTs

- **Options:** A) JWT in localStorage, B) Rails session cookies, C) Custom token in HttpOnly cookie
- **Chosen:** B — Rails session cookies
- **Why:** HttpOnly + Secure + SameSite cookies are immune to XSS token theft. Server-side revocation on logout. See [ADR-026](../adrs/026-cloud-authentication.md).
- **Trade-offs:** Requires CSRF token handling in SPA.

### 13.2 Tenant Isolation Strategy

- **Options:** A) Application-level row scoping, B) PostgreSQL RLS, C) Schema-per-tenant
- **Chosen:** A — Application-level scoping with mandatory test suite
- **Why:** Simpler, adequate for expected scale (< 1000 users). Test suite provides equivalent safety. See [ADR-027](../adrs/027-tenant-isolation.md).
- **Trade-offs:** No database-level guarantee — mitigated by exhaustive tests.

### 13.3 SMTP Multi-Tenant Routing

- **Options:** A) Wildcard subdomain, B) Plus addressing, C) Unique local part
- **Chosen:** A — Wildcard subdomain with UUID slugs
- **Why:** Clean namespace, standard MX routing, unguessable slugs. See [ADR-028](../adrs/028-cloud-smtp-routing.md).
- **Trade-offs:** Longer email addresses. Acceptable.

### 13.4 Project Auto-Creation at Registration

- **Options:** A) User creates project manually after registration, B) Auto-create at registration
- **Chosen:** B — Auto-create project + API key at registration
- **Why:** Minimizes time-to-value. User registers → project exists → SMTP config shown → send test email. Zero extra steps.
- **Trade-offs:** Project slug is auto-generated (UUID), not user-chosen. Acceptable — cloud slugs should be unguessable.

### 13.5 GitHub OAuth: Required or Optional

- **Options:** A) Email-only registration, B) GitHub-only, C) Both (GitHub optional)
- **Chosen:** C — Both, GitHub optional
- **Why:** Email registration has zero dependencies. GitHub OAuth adds convenience for developers who prefer it. Making GitHub optional means cloud works even without configuring OAuth credentials.
- **Trade-offs:** Two auth paths to maintain. Minimal — the session mechanism is the same.

### 13.6 Limit Enforcement: Soft vs Hard

- **Options:** A) Hard limits (reject at limit), B) Soft limits (warn, allow small overages)
- **Chosen:** A — Hard limits
- **Why:** The limits are the conversion mechanism. Soft limits dilute the incentive to self-host. The goal is for users to hit the wall and think "I need the self-hosted version."
- **Trade-offs:** Slightly worse UX at the limit. Mitigated by clear messaging and one-click self-hosting path.

---

## 14. Implementation Plan

### Step 1: Database & Models

1. Create migration for `users` table
2. Create migration for `users_projects` table
3. Create migration for `sessions` table (ActiveRecord session store)
4. Create `UserRecord` and `UsersProjectRecord` AR models
5. Create domain entity `User` and events (`UserRegistered`, `UserVerified`, `UserSignedIn`)
6. Add `has_many :users_projects` to `ProjectRecord`
7. Run migrations, verify schema

### Step 2: Mode Flag & Infrastructure

1. Implement `CloudMode` concern with `cloud_mode?` / `standalone_mode?` helpers
2. Implement `Inboxed::Features` module for feature flags
3. Implement `Inboxed::CurrentTenant` context object
4. Configure ActiveRecord session store (conditional on cloud mode)
5. Update status endpoint to include `mode`, `features`, `user`, `limits`
6. **Verify:** `INBOXED_MODE=cloud` activates cloud behavior, `standalone` is unchanged

### Step 3: Registration & Verification

1. Create `Auth::RegistrationsController`
2. Create `Auth::VerificationsController`
3. Create `RegisterUser` application service (with auto-create project + API key)
4. Create `VerifyUser` application service
5. Create `SendVerificationEmail` service
6. Create `UserMailer` with verification and password reset templates
7. Add auth routes (cloud-only constraint)
8. **Verify:** Register → email sent → click link → verified → session created

### Step 4: Session Auth & Login

1. Create `Auth::SessionsController` (create, show, destroy)
2. Create `AuthenticateUser` application service
3. Add CSRF protection for cloud mode
4. Update `Admin::BaseController` to switch between admin token and session auth
5. **Verify:** Login with email/password → session cookie set → subsequent requests authenticated → logout destroys session

### Step 5: GitHub OAuth (Optional)

1. Add `omniauth-github` gem
2. Create `Auth::OauthController` with GitHub flow
3. Wire find-or-create user logic
4. **Verify:** GitHub login → user created (auto-verified) → session created → redirected to dashboard

### Step 6: Tenant Isolation

1. Implement `CurrentTenant.scope` in all read models
2. Add `CurrentTenant.owns_project?` checks in controllers
3. Update all admin controllers to scope queries in cloud mode
4. Create tenant isolation test suite (`spec/security/tenant_isolation_spec.rb`)
5. **Verify:** User A cannot access User B's projects, inboxes, emails, endpoints via any API path

### Step 7: Free Tier Limits

1. Implement `Inboxed::CloudLimits` module
2. Add limit checks to: `CreateProject`, `CreateInbox`, `PersistEmail`, `CreateHttpEndpoint`, `CaptureHttpRequest`, `IssueApiKey`
3. Add limit check to SMTP handler (email count, inbox count, rate limit)
4. Add `LimitExceeded` error handler to render 429 with self-hosting CTA
5. Add cloud-specific Rack::Attack rules (60 req/min)
6. **Verify:** Create 5 inboxes → 6th returns 429 with limit message

### Step 8: SMTP Multi-Tenant Routing

1. Update SMTP handler with `route_cloud` method
2. Implement wildcard subdomain parsing
3. Implement auto-create inbox on first email
4. Add per-project SMTP rate limiting (10/hour)
5. Add email body size cap (100KB)
6. **Verify:** Send email to `test@{slug}.inboxed.dev` → inbox auto-created → email stored → 11th email in hour rejected

### Step 9: Dashboard — Auth Pages

1. Create `/register` page with email/password + GitHub OAuth
2. Create `/verify` landing page (success/error states)
3. Create `/forgot-password` page
4. Create `/reset-password` page
5. Update `/login` page: show email/password form in cloud mode, admin token in standalone
6. Update `authStore` initialization to detect mode and use session-based auth
7. Update API client: cookie auth in cloud, Bearer token in standalone
8. **Verify:** Full registration flow works in browser

### Step 10: Dashboard — Limit Banners & Cloud UX

1. Create `LimitBanner.svelte` component
2. Add limit banners to: inbox list, email list, endpoint list, API keys page
3. Add usage display to sidebar (`12/50 emails`)
4. Add free tier info to sidebar footer
5. Update project settings for cloud mode (read-only slug, locked TTL, SMTP config)
6. Hide "New Project" button (cloud: 1 project max)
7. Show user email in sidebar footer (instead of "Admin")
8. Add self-hosting CTA to limit exceeded modals
9. **Verify:** Approach limit → warning banner → hit limit → error banner with CTA

### Step 11: Docker & Deploy

1. Create `docker-compose.cloud.yml` overlay
2. Create `.env.cloud.example` with all cloud env vars
3. Disable MCP service in cloud compose (`replicas: 0`)
4. Configure outbound SMTP for verification emails
5. Document DNS setup for cloud (wildcard MX + A records)
6. **Verify:** `docker compose -f ... up` starts cloud mode, MCP not running, registration works

### Step 12: Cleanup & Abuse Prevention

1. Create `CloudCleanupJob` (aggressive: expired data + unverified users + stale sessions)
2. Add to `config/recurring.yml` (every 5 minutes)
3. Add registration rate limiting (3 accounts/IP/hour)
4. Add `fail2ban` configuration for SMTP port
5. **Verify:** Unverified user deleted after 24h, expired data cleaned every 5min

### Step 13: Testing

1. RSpec: registration, verification, login, logout, password reset
2. RSpec: tenant isolation test suite (exhaustive, every resource)
3. RSpec: free tier limit enforcement (every limit)
4. RSpec: SMTP cloud routing (subdomain parsing, auto-create inbox, rate limits)
5. RSpec: feature flags (cloud vs standalone behavior)
6. RSpec: GitHub OAuth flow
7. Vitest: auth pages, limit banners, cloud-specific UI
8. Integration: register → verify → login → send email → hit limit → see CTA
9. Verify standalone mode is completely unaffected (run full existing test suite)
10. `bundle exec standardrb` — zero offenses
11. `svelte-check` — zero errors

---

## 15. Exit Criteria

### Registration & Auth

- [ ] **EC-001:** `POST /auth/register` creates user with hashed password and verification token
- [ ] **EC-002:** Verification email sent with secure token link
- [ ] **EC-003:** `GET /auth/verify?token=...` verifies user and creates session
- [ ] **EC-004:** Unverified user cannot login (403 with "verify email" message)
- [ ] **EC-005:** `POST /auth/sessions` creates session cookie for verified user
- [ ] **EC-006:** `DELETE /auth/sessions` destroys session
- [ ] **EC-007:** `GET /auth/me` returns current user data
- [ ] **EC-008:** Password reset flow: request → email → reset → login works
- [ ] **EC-009:** GitHub OAuth: login → user created (auto-verified) → session created
- [ ] **EC-010:** Registration auto-creates project with UUID slug and API key
- [ ] **EC-011:** Auth routes return 404 in standalone mode

### Tenant Isolation

- [ ] **EC-012:** User A cannot list User B's projects
- [ ] **EC-013:** User A cannot view User B's project by ID
- [ ] **EC-014:** User A cannot list User B's inboxes
- [ ] **EC-015:** User A cannot view User B's emails
- [ ] **EC-016:** User A cannot access User B's HTTP endpoints
- [ ] **EC-017:** User A cannot access User B's API keys
- [ ] **EC-018:** SMTP: email to User B's slug doesn't appear in User A's inbox
- [ ] **EC-019:** `CurrentTenant` raises if not set in cloud mode (fail-open impossible)
- [ ] **EC-020:** Tenant isolation test suite passes in CI

### Free Tier Limits

- [ ] **EC-021:** Cannot create more than 1 project per user
- [ ] **EC-022:** Cannot create more than 5 inboxes per project
- [ ] **EC-023:** Cannot receive more than 50 emails per project
- [ ] **EC-024:** Cannot create more than 6 HTTP endpoints per project
- [ ] **EC-025:** Cannot capture more than 20 requests per endpoint
- [ ] **EC-026:** Cannot create more than 2 API keys per project
- [ ] **EC-027:** SMTP rate limit: 11th email in 1 hour rejected (450)
- [ ] **EC-028:** API rate limit: 61st request in 1 minute → 429
- [ ] **EC-029:** Email body > 100KB rejected by SMTP
- [ ] **EC-030:** Limit exceeded response includes self-hosting CTA URL
- [ ] **EC-031:** Limits do not apply in standalone mode

### Feature Gates

- [ ] **EC-032:** MCP service not running in cloud compose
- [ ] **EC-033:** `features.mcp = false` in cloud status response
- [ ] **EC-034:** HTML email preview disabled in cloud (text + headers only)
- [ ] **EC-035:** TTL locked to 1 hour in cloud (not configurable)
- [ ] **EC-036:** All features enabled in standalone mode

### SMTP Multi-Tenant

- [ ] **EC-037:** Email to `test@{slug}.inboxed.dev` routes to correct project
- [ ] **EC-038:** Email to unknown slug returns 550
- [ ] **EC-039:** Inbox auto-created on first email to new address
- [ ] **EC-040:** Inbox auto-creation respects limit (5 max)
- [ ] **EC-041:** SMTP rate limit enforced per project (10/hour)

### Dashboard

- [ ] **EC-042:** Cloud login page shows email/password + GitHub OAuth
- [ ] **EC-043:** Standalone login page shows admin token field (unchanged)
- [ ] **EC-044:** Registration form works with validation errors
- [ ] **EC-045:** Limit warning banner appears at 80% usage
- [ ] **EC-046:** Limit exceeded banner shows self-hosting CTA
- [ ] **EC-047:** Sidebar shows usage counts (`12/50`) in cloud mode
- [ ] **EC-048:** Sidebar shows user email and "Logout" in cloud mode
- [ ] **EC-049:** Project settings shows SMTP config with cloud server details
- [ ] **EC-050:** "New Project" button hidden in cloud mode

### Cleanup & Security

- [ ] **EC-051:** Unverified accounts deleted after 24 hours
- [ ] **EC-052:** Expired data cleaned every 5 minutes
- [ ] **EC-053:** Stale sessions cleaned after 7 days
- [ ] **EC-054:** Registration rate limited (3 accounts/IP/hour)
- [ ] **EC-055:** CSRF protection active for cloud session requests

### Integration

- [ ] **EC-056:** Full flow: register → verify → login → configure SMTP → send email → see in dashboard → hit limit → see CTA → copy self-hosting command
- [ ] **EC-057:** Standalone mode: entire existing test suite passes unchanged
- [ ] **EC-058:** Cloud mode: `docker compose -f ... up` starts correctly, MCP disabled
- [ ] **EC-059:** `bundle exec standardrb` passes
- [ ] **EC-060:** `svelte-check` passes
- [ ] **EC-061:** All RSpec and Vitest tests pass

---

## 16. Open Questions

1. **Email delivery provider for verification emails:** Should we use a dedicated transactional email service (Resend, Postmark) or an outbound SMTP relay? Recommendation: configurable via `OUTBOUND_SMTP_*` env vars — let the operator choose. Document Resend as the cheapest option (~$0 for the volume we'll have).

2. **Account deletion:** Should users be able to delete their account? Recommendation: yes, add a "Delete my account" button in settings. `CASCADE` deletes handle data cleanup. Required for GDPR compliance if EU users register.

3. **Magic link login (passwordless):** Should we offer magic link login as an alternative? Recommendation: not in this spec — email + password + GitHub OAuth covers the use cases. Revisit if users request it.

4. **Rate limit for failed logins:** How many failed login attempts before lockout? Recommendation: existing Rack::Attack rule (5 failures per 5 minutes per IP) is sufficient. No per-account lockout — that enables denial of service against specific emails.

5. **Monitoring dashboard:** Should we build an internal admin dashboard for monitoring cloud health (registrations, active users, storage usage)? Recommendation: not in this spec. Use `rails console` and SQL queries initially. Build a dashboard when there's enough usage to warrant it.

6. **Custom domains:** Should cloud users be able to bring their own domain? Recommendation: not in this spec. Wildcard subdomain is sufficient for the free tier. Custom domains would require per-user DNS verification and certificate management — out of scope for a marketing funnel.
