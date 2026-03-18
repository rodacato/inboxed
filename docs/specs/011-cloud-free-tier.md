# Spec 011 — Multi-User: Organizations, Invitations & Trial

> **Updated 2026-03-16:** Complete rewrite. Replaced dual-mode (`standalone`/`cloud`) design with a unified multi-user model. Inboxed is always multi-user. Organizations are the tenant. Trial is time-based, not resource-based. No `INBOXED_MODE` flag.

> Add multi-user support to Inboxed. Organizations group users and projects. The site operator controls registration (open, invite-only, or closed) and trial duration. Same codebase, same Docker image — configuration via env vars, not code branches.

**Phase:** 9
**Status:** implemented
**Created:** 2026-03-16
**Depends on:** [001 — Architecture](001-architecture.md), [009 — Usability](009-usability.md) (auth abstraction, feature flags)
**ADRs:** [022 — Cloud Free Tier](../adrs/022-cloud-free-tier.md) (superseded in part), [026 — Authentication](../adrs/026-cloud-authentication.md) (rewritten), [027 — Tenant Isolation](../adrs/027-tenant-isolation.md) (rewritten), [028 — Cloud SMTP Routing](../adrs/028-cloud-smtp-routing.md), [029 — Organization & Trial](../adrs/029-organization-trial.md)
**Expert panel:** Security Engineer, Full-Stack Engineer, API Design Architect, Product Manager, DevOps Engineer, UX/UI Designer

---

## 1. Objective

Make Inboxed multi-user from day one. An operator installs Inboxed, creates their admin account, and can then invite team members or open registration for external users with a time-limited trial.

**What this replaces:** The original spec 011 had two modes (`INBOXED_MODE=standalone` vs `cloud`) with separate auth flows, resource-based limits, and a public cloud instance as a marketing funnel. This rewrite eliminates the mode flag. Inboxed is always multi-user — the operator configures how open it is.

### Three deployment scenarios, one codebase

| Scenario | Registration | Trial | Example |
|---|---|---|---|
| **Solo dev** | Closed — setup wizard only | None | `localhost`, personal VPS |
| **Team** | Invite-only — admin invites members | None | Company VPS, shared staging |
| **Public instance** | Open — anyone registers | 7 days | `inboxed.notdefined.dev` or any operator |

Configuration:
```bash
REGISTRATION_MODE=open        # 'open' | 'invite_only' | 'closed'
TRIAL_DURATION_DAYS=7         # 0 = permanent access immediately
```

**Guiding principle:** No `if mode == ...` in the code. One auth model. One tenant model. One set of controllers. Configuration via env vars.

---

## 2. Current State

### What exists

- **Auth abstraction** (spec 009) — `authStore` with mode, features, user fields
- **Feature flag system** — `/admin/status` returns enabled features
- **Admin token auth** — `INBOXED_ADMIN_TOKEN` for dashboard (to be replaced)
- **Per-project API keys** — Bearer token auth for programmatic access (unchanged)
- **Project model** — `project_id` on every resource
- **ActionMailer** — configured but not used for user-facing emails yet

### What this spec adds

- `organizations`, `memberships`, `invitations` tables
- `sessions` table for ActiveRecord session store
- `site_admin` flag on users
- `organization_id` on projects
- Setup wizard (first boot → create admin)
- Registration flow with email verification (when SMTP configured)
- GitHub OAuth (optional)
- Invitation system (invite by email, accept via token)
- Organization-scoped tenant isolation (`CurrentTenant`)
- Time-based trial on organizations
- Role-based access (site_admin, org_admin, member)
- Outbound SMTP configuration for transactional emails
- Updated dashboard: login, register, setup, invite, trial banners

### What this spec removes (vs original spec 011)

- ~~`INBOXED_MODE` env var~~ — eliminated
- ~~`CloudMode` concern~~ — replaced by always-active auth
- ~~`CloudLimits` with resource-based limits~~ — replaced by time-based trial
- ~~`docker-compose.cloud.yml` overlay~~ — one compose file
- ~~Wildcard subdomain SMTP routing~~ — moved to optional configuration (ADR-028 still applies if operator wants it)
- ~~Feature gates (MCP disabled, HTML preview disabled)~~ — all features always available

---

## 3. Data Model

### 3.1 New Tables

#### `organizations`

```sql
CREATE TABLE organizations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            VARCHAR NOT NULL,
  slug            VARCHAR NOT NULL,
  trial_ends_at   TIMESTAMPTZ,
  settings        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT organizations_slug_unique UNIQUE (slug)
);

CREATE INDEX idx_organizations_slug ON organizations(slug);
```

#### `users` (replaces admin token)

```sql
CREATE TABLE users (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email                   VARCHAR NOT NULL,
  password_digest         VARCHAR NOT NULL,
  site_admin              BOOLEAN DEFAULT false,
  github_uid              VARCHAR,
  github_username         VARCHAR,
  verified_at             TIMESTAMPTZ,
  verification_token      VARCHAR,
  verification_sent_at    TIMESTAMPTZ,
  password_reset_token    VARCHAR,
  password_reset_sent_at  TIMESTAMPTZ,
  last_sign_in_at         TIMESTAMPTZ,
  sign_in_count           INTEGER DEFAULT 0,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT users_email_unique UNIQUE (email),
  CONSTRAINT users_github_uid_unique UNIQUE (github_uid)
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_verification_token ON users(verification_token)
  WHERE verification_token IS NOT NULL;
```

#### `memberships`

```sql
CREATE TABLE memberships (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  role            VARCHAR NOT NULL DEFAULT 'member',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT memberships_unique UNIQUE (user_id, organization_id),
  CONSTRAINT memberships_role_check CHECK (role IN ('org_admin', 'member'))
);

CREATE INDEX idx_memberships_user ON memberships(user_id);
CREATE INDEX idx_memberships_org ON memberships(organization_id);
```

#### `invitations`

```sql
CREATE TABLE invitations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  email           VARCHAR NOT NULL,
  role            VARCHAR NOT NULL DEFAULT 'member',
  token           VARCHAR NOT NULL,
  invited_by_id   UUID NOT NULL REFERENCES users(id),
  accepted_at     TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT invitations_token_unique UNIQUE (token)
);

CREATE INDEX idx_invitations_token ON invitations(token);
CREATE INDEX idx_invitations_org_email ON invitations(organization_id, email);
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

### 3.2 Schema Changes to Existing Tables

```sql
-- Add organization_id to projects
ALTER TABLE projects ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
CREATE INDEX idx_projects_organization ON projects(organization_id);
```

### 3.3 ActiveRecord Models

```ruby
# app/models/organization_record.rb
class OrganizationRecord < ApplicationRecord
  self.table_name = "organizations"

  has_many :memberships, foreign_key: :organization_id, dependent: :destroy
  has_many :users, through: :memberships, source: :user, class_name: "UserRecord"
  has_many :projects, class_name: "ProjectRecord", foreign_key: :organization_id, dependent: :destroy
  has_many :invitations, foreign_key: :organization_id, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  def trial?
    trial_ends_at.present?
  end

  def trial_active?
    trial? && trial_ends_at > Time.current
  end

  def trial_expired?
    trial? && trial_ends_at <= Time.current
  end

  def permanent?
    trial_ends_at.nil?
  end

  def days_remaining
    return nil unless trial?
    [(trial_ends_at - Time.current).to_i / 1.day, 0].max
  end

  def active?
    permanent? || trial_active?
  end
end

# app/models/user_record.rb
class UserRecord < ApplicationRecord
  self.table_name = "users"
  has_secure_password

  has_many :memberships, foreign_key: :user_id, dependent: :destroy
  has_many :organizations, through: :memberships, source: :organization,
           class_name: "OrganizationRecord"

  validates :email, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, on: :create

  scope :verified, -> { where.not(verified_at: nil) }

  def organization
    organizations.first  # User belongs to one org (enforced at service level)
  end

  def role_in(org)
    return "site_admin" if site_admin?
    memberships.find_by(organization: org)&.role || "member"
  end

  def site_admin?
    site_admin
  end

  def verified?
    verified_at.present?
  end
end

# app/models/membership_record.rb
class MembershipRecord < ApplicationRecord
  self.table_name = "memberships"

  belongs_to :user, class_name: "UserRecord"
  belongs_to :organization, class_name: "OrganizationRecord"

  validates :role, inclusion: { in: %w[org_admin member] }
end

# app/models/invitation_record.rb
class InvitationRecord < ApplicationRecord
  self.table_name = "invitations"

  belongs_to :organization, class_name: "OrganizationRecord"
  belongs_to :invited_by, class_name: "UserRecord"

  validates :email, presence: true
  validates :token, presence: true, uniqueness: true
  validates :role, inclusion: { in: %w[org_admin member] }

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def accepted?
    accepted_at.present?
  end
end

# app/models/project_record.rb (updated)
class ProjectRecord < ApplicationRecord
  # ... existing code ...
  belongs_to :organization, class_name: "OrganizationRecord", optional: true
  # optional: true during migration period — becomes required after backfill
end
```

### 3.4 Domain Layer

#### Entities

```ruby
# app/domain/entities/user.rb
module Inboxed::Domain::Entities
  class User < Dry::Struct
    attribute :id, Types::UUID
    attribute :email, Types::String
    attribute :verified, Types::Bool
    attribute :site_admin, Types::Bool
    attribute :github_username, Types::String.optional
    attribute :last_sign_in_at, Types::Time.optional
    attribute :created_at, Types::Time
  end
end

# app/domain/entities/organization.rb
module Inboxed::Domain::Entities
  class Organization < Dry::Struct
    attribute :id, Types::UUID
    attribute :name, Types::String
    attribute :slug, Types::String
    attribute :trial_ends_at, Types::Time.optional
    attribute :created_at, Types::Time

    def trial? = trial_ends_at.present?
    def active? = !trial? || trial_ends_at > Time.current
  end
end
```

#### Events

```ruby
# app/domain/events/
class UserRegistered < Base
  attribute :user_id, Types::UUID
  attribute :email, Types::String
  attribute :organization_id, Types::UUID
  attribute :registration_method, Types::String  # 'setup' | 'email' | 'github' | 'invitation'
end

class UserVerified < Base
  attribute :user_id, Types::UUID
  attribute :email, Types::String
end

class UserInvited < Base
  attribute :invitation_id, Types::UUID
  attribute :organization_id, Types::UUID
  attribute :email, Types::String
  attribute :role, Types::String
  attribute :invited_by_id, Types::UUID
end

class InvitationAccepted < Base
  attribute :invitation_id, Types::UUID
  attribute :user_id, Types::UUID
  attribute :organization_id, Types::UUID
end

class TrialExpired < Base
  attribute :organization_id, Types::UUID
  attribute :name, Types::String
end
```

---

## 4. Roles & Permissions

### 4.1 Permission Matrix

| Action | site_admin | org_admin | member | trial_expired |
|---|---|---|---|---|
| View projects & data | ✅ | ✅ | ✅ | ✅ (read-only) |
| Create project | ✅ | ✅ | ❌ | ❌ |
| Delete project | ✅ | ✅ | ❌ | ❌ |
| Manage API keys | ✅ | ✅ | ❌ | ❌ |
| Invite members | ✅ | ✅ | ❌ | ❌ |
| Remove members | ✅ | ✅ | ❌ | ❌ |
| Send email (SMTP) | ✅ | ✅ | ✅ | ❌ |
| Create HTTP endpoints | ✅ | ✅ | ✅ | ❌ |
| Manage org settings | ✅ | ✅ | ❌ | ❌ |
| Manage all orgs | ✅ | ❌ | ❌ | ❌ |
| Manage instance settings | ✅ | ❌ | ❌ | ❌ |
| Grant permanent access | ✅ | ❌ | ❌ | ❌ |

### 4.2 Authorization

```ruby
# lib/inboxed/authorization.rb
module Inboxed
  class Authorization
    def initialize(user:, organization:)
      @user = user
      @org = organization
      @role = user.role_in(organization)
    end

    def can?(action)
      return false if trial_expired? && write_action?(action)
      PERMISSIONS.fetch(action, []).include?(@role)
    end

    def trial_expired?
      @org.trial_expired?
    end

    private

    PERMISSIONS = {
      view_data:          %w[site_admin org_admin member],
      create_project:     %w[site_admin org_admin],
      delete_project:     %w[site_admin org_admin],
      manage_api_keys:    %w[site_admin org_admin],
      invite_members:     %w[site_admin org_admin],
      remove_members:     %w[site_admin org_admin],
      manage_org:         %w[site_admin org_admin],
      manage_instance:    %w[site_admin],
      grant_permanent:    %w[site_admin]
    }.freeze

    def write_action?(action)
      !%i[view_data].include?(action)
    end
  end
end
```

---

## 5. Authentication Flows

See [ADR-026](../adrs/026-cloud-authentication.md) for session cookie rationale.

### 5.1 Routes

```ruby
# config/routes.rb (additions)

# Setup wizard (first boot)
get  "setup", to: "setup#show"
post "setup", to: "setup#create"

# Auth
namespace :auth do
  post   "register",            to: "registrations#create"
  get    "verify",              to: "verifications#show"
  post   "resend-verification", to: "verifications#create"
  post   "sessions",            to: "sessions#create"
  get    "me",                  to: "sessions#show"
  delete "sessions",            to: "sessions#destroy"
  post   "forgot-password",     to: "passwords#create"
  put    "reset-password",      to: "passwords#update"
  get    "github",              to: "oauth#github"
  get    "github/callback",     to: "oauth#github_callback"
  post   "accept-invitation",   to: "invitations#accept"
  get    "invitation",          to: "invitations#show"
end

# Organization management (org_admin+)
namespace :admin do
  resources :members, only: [:index, :create, :destroy]
  resources :invitations, only: [:index, :create, :destroy]
  resource  :organization, only: [:show, :update]
end

# Site admin
namespace :site_admin do
  resources :organizations, only: [:index, :show, :update, :destroy] do
    member do
      post :grant_permanent   # Remove trial
    end
  end
  resources :users, only: [:index, :show, :destroy]
  resource  :settings, only: [:show, :update]
end
```

### 5.2 Setup Wizard (First Boot)

```ruby
# app/controllers/setup_controller.rb
class SetupController < ApplicationController
  before_action :ensure_setup_available

  def show
    render json: { setup_required: true }
  end

  def create
    return head :forbidden unless valid_setup_token?

    result = Inboxed::Application::Services::SetupInstance.call(
      email: params[:email],
      password: params[:password],
      org_name: params[:org_name] || "Default",
      setup_token: params[:setup_token]
    )

    session[:user_id] = result.user.id
    render json: { data: serialize_user(result.user) }, status: :created
  end

  private

  def ensure_setup_available
    redirect_to "/login" if Inboxed::Settings.setup_completed?
  end

  def valid_setup_token?
    expected = ENV["INBOXED_SETUP_TOKEN"]
    return false unless expected.present?
    ActiveSupport::SecurityUtils.secure_compare(params[:setup_token].to_s, expected)
  end
end
```

```ruby
# app/application/services/setup_instance.rb
module Inboxed::Application::Services
  class SetupInstance
    def self.call(email:, password:, org_name:, setup_token:)
      org = OrganizationRecord.create!(
        name: org_name,
        slug: org_name.parameterize.presence || SecureRandom.uuid.split("-").first,
        trial_ends_at: nil  # Permanent — this is the operator
      )

      user = UserRecord.create!(
        email: email,
        password: password,
        site_admin: true,
        verified_at: Time.current  # Auto-verified — they have server access
      )

      MembershipRecord.create!(
        user: user,
        organization: org,
        role: "org_admin"
      )

      Inboxed::Settings.set(:setup_completed_at, Time.current)

      # Publish event
      Inboxed::Infrastructure::EventStore::Bus.publish(
        Inboxed::Domain::Events::UserRegistered.new(
          user_id: user.id,
          email: user.email,
          organization_id: org.id,
          registration_method: "setup"
        ),
        stream: "user-#{user.id}"
      )

      OpenStruct.new(user: user, organization: org)
    end
  end
end
```

### 5.3 Registration (Open Mode)

```ruby
# app/application/services/register_user.rb
module Inboxed::Application::Services
  class RegisterUser
    def self.call(email:, password:, invitation_token: nil)
      new(email:, password:, invitation_token:).call
    end

    def initialize(email:, password:, invitation_token:)
      @email = email.downcase.strip
      @password = password
      @invitation_token = invitation_token
    end

    def call
      validate_registration_allowed!

      if @invitation_token
        register_via_invitation
      else
        register_open
      end
    end

    private

    def validate_registration_allowed!
      mode = ENV.fetch("REGISTRATION_MODE", "closed")
      return if @invitation_token  # Invitations always work
      raise RegistrationClosed unless mode == "open"
    end

    def register_open
      # Create user
      user = create_user(verified: !outbound_smtp_configured?)

      # Create org with trial
      trial_days = ENV.fetch("TRIAL_DURATION_DAYS", "7").to_i
      org = OrganizationRecord.create!(
        name: "#{@email.split('@').first}'s workspace",
        slug: SecureRandom.uuid.split("-").first,
        trial_ends_at: trial_days > 0 ? trial_days.days.from_now : nil
      )

      MembershipRecord.create!(user: user, organization: org, role: "org_admin")

      # Create default project
      create_default_project(org)

      # Send verification if SMTP configured
      SendVerificationEmail.call(user: user) if outbound_smtp_configured? && !user.verified?

      publish_event(user, org, "email")
      success(user)
    end

    def register_via_invitation
      invitation = InvitationRecord.pending.find_by!(token: @invitation_token)
      raise InvitationExpired if invitation.expired?

      user = create_user(verified: !outbound_smtp_configured?)

      MembershipRecord.create!(
        user: user,
        organization: invitation.organization,
        role: invitation.role
      )

      invitation.update!(accepted_at: Time.current)

      SendVerificationEmail.call(user: user) if outbound_smtp_configured? && !user.verified?

      publish_event(user, invitation.organization, "invitation")
      success(user)
    end

    def create_user(verified: false)
      UserRecord.create!(
        email: @email,
        password: @password,
        verified_at: verified ? Time.current : nil,
        verification_token: verified ? nil : SecureRandom.urlsafe_base64(32),
        verification_sent_at: verified ? nil : Time.current
      )
    end

    def create_default_project(org)
      project = ProjectRecord.create!(
        name: "My Project",
        slug: SecureRandom.uuid.split("-").first,
        organization: org,
        default_ttl_hours: 24
      )

      Inboxed::Services::IssueApiKey.call(
        project_id: project.id,
        label: "Default key"
      )
    end

    def outbound_smtp_configured?
      ENV["OUTBOUND_SMTP_HOST"].present?
    end

    def publish_event(user, org, method)
      Inboxed::Infrastructure::EventStore::Bus.publish(
        Inboxed::Domain::Events::UserRegistered.new(
          user_id: user.id, email: user.email,
          organization_id: org.id, registration_method: method
        ),
        stream: "user-#{user.id}"
      )
    end

    def success(user) = OpenStruct.new(success?: true, user: user, errors: [])

    class RegistrationClosed < StandardError; end
    class InvitationExpired < StandardError; end
  end
end
```

### 5.4 Invitation Flow

```ruby
# app/application/services/invite_user.rb
module Inboxed::Application::Services
  class InviteUser
    def self.call(organization:, email:, role:, invited_by:)
      invitation = InvitationRecord.create!(
        organization: organization,
        email: email.downcase.strip,
        role: role,
        token: SecureRandom.urlsafe_base64(32),
        invited_by: invited_by,
        expires_at: 7.days.from_now
      )

      # Send invitation email if SMTP configured
      if ENV["OUTBOUND_SMTP_HOST"].present?
        InvitationMailer.invite(invitation).deliver_later
      end

      Inboxed::Infrastructure::EventStore::Bus.publish(
        Inboxed::Domain::Events::UserInvited.new(
          invitation_id: invitation.id,
          organization_id: organization.id,
          email: email,
          role: role,
          invited_by_id: invited_by.id
        ),
        stream: "organization-#{organization.id}"
      )

      invitation
    end
  end
end
```

### 5.5 Session Authentication

```ruby
# app/controllers/auth/sessions_controller.rb
module Auth
  class SessionsController < ApplicationController
    def create
      user = UserRecord.find_by(email: params[:email]&.downcase&.strip)

      if user&.authenticate(params[:password])
        if requires_verification? && !user.verified?
          render json: { error: "email_not_verified" }, status: :forbidden
        else
          start_session(user)
          render json: { data: serialize_user_with_org(user) }
        end
      else
        render json: { error: "invalid_credentials" }, status: :unauthorized
      end
    end

    def show
      if current_user
        render json: { data: serialize_user_with_org(current_user) }
      else
        head :unauthorized
      end
    end

    def destroy
      reset_session
      head :no_content
    end

    private

    def start_session(user)
      session[:user_id] = user.id
      user.update!(
        last_sign_in_at: Time.current,
        sign_in_count: user.sign_in_count + 1
      )
    end

    def requires_verification?
      ENV["OUTBOUND_SMTP_HOST"].present?
    end
  end
end
```

---

## 6. Tenant Isolation

See [ADR-027](../adrs/027-tenant-isolation.md) for the full rationale.

### 6.1 CurrentTenant (Always Active)

```ruby
# lib/inboxed/current_tenant.rb
module Inboxed
  class CurrentTenant
    thread_mattr_accessor :organization_id, :user_id, :user_role

    def self.set(user:, organization:)
      self.user_id = user.id
      self.organization_id = organization.id
      self.user_role = user.role_in(organization)
      yield
    ensure
      self.user_id = nil
      self.organization_id = nil
      self.user_role = nil
    end

    def self.scope_projects(relation)
      return relation if site_admin?
      raise TenantNotSet unless set?
      relation.where(organization_id: organization_id)
    end

    def self.set?       = organization_id.present?
    def self.site_admin? = user_role == "site_admin"
    def self.org_admin?  = user_role.in?(%w[site_admin org_admin])

    class TenantNotSet < StandardError; end
  end
end
```

### 6.2 Controller Integration

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include ActionController::Cookies

  private

  def current_user
    @current_user ||= UserRecord.find_by(id: session[:user_id])
  end

  def require_auth!
    head :unauthorized unless current_user
  end

  def require_active_org!
    org = current_user&.organization
    return head :unauthorized unless org

    unless org.active?
      render json: {
        error: "trial_expired",
        message: "Your trial has expired. Contact the administrator for permanent access.",
        trial_ended_at: org.trial_ends_at&.iso8601
      }, status: :forbidden
    end
  end

  def with_tenant(&block)
    return yield unless current_user

    org = current_user.organization
    return head :unauthorized unless org

    Inboxed::CurrentTenant.set(user: current_user, organization: org, &block)
  end
end

# app/controllers/admin/base_controller.rb (rewritten)
module Admin
  class BaseController < ApplicationController
    around_action :with_tenant
    before_action :require_auth!

    private

    def current_project
      Inboxed::CurrentTenant.scope_projects(ProjectRecord).find(params[:project_id])
    end
  end
end
```

### 6.3 Trial Enforcement

Write actions check both auth and trial status:

```ruby
# app/controllers/concerns/trial_enforced.rb
module TrialEnforced
  extend ActiveSupport::Concern

  included do
    before_action :require_active_org!, only: [:create, :update, :destroy]
  end
end
```

Read actions work even after trial expiry — users can still view their data.

---

## 7. Outbound Email (Transactional)

Inboxed needs to send emails for: verification, password reset, invitations. This uses a standard SMTP relay (Resend, Postmark, Mailgun, or any provider).

**This is separate from Inboxed's SMTP catcher** — the catcher receives test emails, the relay sends system emails.

### 7.1 Configuration

```bash
# Outbound SMTP relay for system emails
OUTBOUND_SMTP_HOST=smtp.resend.com
OUTBOUND_SMTP_PORT=587
OUTBOUND_SMTP_USER=resend
OUTBOUND_SMTP_PASS=re_xxxx
OUTBOUND_FROM_EMAIL=noreply@yourdomain.com
```

### 7.2 ActionMailer Setup

```ruby
# config/environments/production.rb
if ENV["OUTBOUND_SMTP_HOST"].present?
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV["OUTBOUND_SMTP_HOST"],
    port: ENV.fetch("OUTBOUND_SMTP_PORT", 587).to_i,
    user_name: ENV["OUTBOUND_SMTP_USER"],
    password: ENV["OUTBOUND_SMTP_PASS"],
    authentication: :plain,
    enable_starttls: true
  }
end
```

### 7.3 Mailers

```ruby
# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  default from: -> { ENV.fetch("OUTBOUND_FROM_EMAIL", "noreply@inboxed.dev") }

  def verification(user)
    @user = user
    @url = "#{base_url}/auth/verify?token=#{user.verification_token}"
    mail(to: user.email, subject: "Verify your Inboxed account")
  end

  def password_reset(user)
    @user = user
    @url = "#{base_url}/reset-password?token=#{user.password_reset_token}"
    mail(to: user.email, subject: "Reset your Inboxed password")
  end
end

# app/mailers/invitation_mailer.rb
class InvitationMailer < ApplicationMailer
  default from: -> { ENV.fetch("OUTBOUND_FROM_EMAIL", "noreply@inboxed.dev") }

  def invite(invitation)
    @invitation = invitation
    @org = invitation.organization
    @url = "#{base_url}/auth/invitation?token=#{invitation.token}"
    mail(to: invitation.email, subject: "You're invited to #{@org.name} on Inboxed")
  end
end
```

### 7.4 Graceful Degradation

If `OUTBOUND_SMTP_HOST` is not set:
- Users are **auto-verified** at registration (no email sent)
- Password reset is unavailable (admin resets manually via site admin panel)
- Invitations still work but the invite link must be shared manually (dashboard shows copyable link)
- Dashboard shows notice: "Configure outbound SMTP for email verification and password reset"

---

## 8. Dashboard Changes

### 8.1 New Routes

```
src/routes/
├── setup/+page.svelte              → first boot setup wizard
├── register/+page.svelte           → registration (when open)
├── verify/+page.svelte             → email verification landing
├── forgot-password/+page.svelte    → password reset request
├── reset-password/+page.svelte     → password reset form
├── invitation/+page.svelte         → accept invitation
├── login/+page.svelte              → email/password + GitHub OAuth
└── settings/
    ├── members/+page.svelte        → org member management
    ├── invitations/+page.svelte    → pending invitations
    └── organization/+page.svelte   → org settings
```

### 8.2 Setup Wizard (First Boot)

```
┌──────────────────────────────────────────────────┐
│              [@] inboxed                           │
│              Welcome. Let's set up your instance.  │
│                                                    │
│  Setup Token                                       │
│  ┌──────────────────────────────────────────────┐  │
│  │ (from INBOXED_SETUP_TOKEN env var)           │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  Organization Name                                 │
│  ┌──────────────────────────────────────────────┐  │
│  │ My Team                                      │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  Admin Email                                       │
│  ┌──────────────────────────────────────────────┐  │
│  │ admin@example.com                            │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  Password                                          │
│  ┌──────────────────────────────────────────────┐  │
│  │ ••••••••••                                   │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  [        Create admin account        ]            │
│                                                    │
└──────────────────────────────────────────────────┘
```

### 8.3 Trial Banner

```
┌─ ⏱ Trial: 3 days remaining ──────────────────────────────────────────────┐
│  Your trial ends on Mar 23. Contact the administrator for permanent       │
│  access, or self-host your own instance.                                  │
│  [📖 Self-hosting guide]                                          [Dismiss]│
└───────────────────────────────────────────────────────────────────────────┘
```

```
┌─ 🚫 Trial expired ───────────────────────────────────────────────────────┐
│  Your trial has expired. You can still view existing data.                │
│  Contact the administrator to continue using Inboxed.                     │
└───────────────────────────────────────────────────────────────────────────┘
```

### 8.4 Members Page (org_admin)

```
┌─ Members ─────────────────────────────────────────────────────────────────┐
│                                                    [+ Invite member]       │
│────────────────────────────────────────────────────────────────────────────│
│  admin@example.com          org_admin     Joined Mar 16     (you)         │
│  dev@example.com            member        Joined Mar 17     [Remove]      │
│                                                                            │
│  Pending invitations                                                       │
│  qa@example.com             member        Expires Mar 23    [Revoke]      │
└───────────────────────────────────────────────────────────────────────────┘
```

### 8.5 Sidebar (Updated)

```
┌─────────────────────────────────────┐
│  [@] inboxed                        │
│─────────────────────────────────────│
│  🔍 Search                          │
│                                     │
│  My Team                       [⚙]  │  ← org name
│                                     │
│  PROJECT: my-app               [⚙]  │
│    📧 Mail                (12)     │
│    🔗 Hooks In             (3)     │
│    📋 Forms                (1)     │
│    💓 Heartbeats           (1)     │
│                                     │
│  + New Project                      │
│─────────────────────────────────────│
│  ⏱ Trial: 3 days left              │  ← only if trial
│─────────────────────────────────────│
│  [🌙]  [● Connected]               │
│  admin@example.com  [Logout]        │
└─────────────────────────────────────┘
```

### 8.6 Auth Store (Updated)

```typescript
// src/lib/stores/auth.store.svelte.ts
interface AuthState {
  isAuthenticated: boolean;
  user: {
    id: string;
    email: string;
    role: 'site_admin' | 'org_admin' | 'member';
    siteAdmin: boolean;
  } | null;
  organization: {
    id: string;
    name: string;
    slug: string;
    trial: boolean;
    trialEndsAt: string | null;
    trialActive: boolean;
    daysRemaining: number | null;
  } | null;
  features: Record<string, boolean>;
  setupRequired: boolean;
}
```

### 8.7 Status Endpoint (Updated)

```json
{
  "status": "ok",
  "version": "1.2.0",
  "setup_completed": true,
  "registration_mode": "invite_only",
  "outbound_smtp_configured": true,
  "features": {
    "mail": true,
    "hooks": true,
    "forms": true,
    "heartbeats": true,
    "mcp": true,
    "html_preview": true
  },
  "user": {
    "id": "...",
    "email": "admin@example.com",
    "role": "org_admin",
    "site_admin": true
  },
  "organization": {
    "id": "...",
    "name": "My Team",
    "slug": "my-team",
    "trial": false,
    "trial_ends_at": null
  }
}
```

---

## 9. Settings Model

Instance-level settings (persisted in DB, managed by site admin):

```ruby
# lib/inboxed/settings.rb
module Inboxed
  class Settings
    # Simple key-value store using a settings table or Rails credentials
    def self.setup_completed?
      get(:setup_completed_at).present?
    end

    def self.get(key)
      SettingRecord.find_by(key: key.to_s)&.value
    end

    def self.set(key, value)
      record = SettingRecord.find_or_initialize_by(key: key.to_s)
      record.update!(value: value.to_s)
    end
  end
end
```

```sql
CREATE TABLE settings (
  id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key   VARCHAR NOT NULL,
  value TEXT,
  CONSTRAINT settings_key_unique UNIQUE (key)
);
```

---

## 10. Cleanup Jobs

```ruby
# app/application/jobs/maintenance_cleanup_job.rb
class MaintenanceCleanupJob < ApplicationJob
  queue_as :default

  def perform
    # Clean expired sessions
    sessions_deleted = Session.where("updated_at < ?", 7.days.ago).delete_all

    # Clean expired invitations
    invitations_deleted = InvitationRecord.expired.where(accepted_at: nil).delete_all

    # Clean unverified users older than 48 hours (if SMTP is configured)
    if ENV["OUTBOUND_SMTP_HOST"].present?
      users_deleted = UserRecord.unverified.where("created_at < ?", 48.hours.ago).destroy_all.count
    end

    Rails.logger.info(
      "MaintenanceCleanup: sessions=#{sessions_deleted} " \
      "invitations=#{invitations_deleted} users=#{users_deleted || 0}"
    )
  end
end
```

```yaml
# config/recurring.yml (additions)
maintenance_cleanup:
  class: MaintenanceCleanupJob
  schedule: every 1 hour
```

---

## 11. Technical Decisions

### 11.1 Single Mode vs Dual Mode

- **Options:** A) Keep `INBOXED_MODE=standalone/cloud`, B) One mode, configure via env vars
- **Chosen:** B — one mode
- **Why:** Eliminates all `if cloud_mode?` branching. Solo dev is just a one-person org. See panel discussion in spec history.
- **Trade-offs:** Setup wizard required even for solo dev. Acceptable — it's 30 seconds.

### 11.2 Organization vs User as Tenant

- **Options:** A) User owns projects directly, B) Organization owns projects
- **Chosen:** B — Organization as tenant. See [ADR-029](../adrs/029-organization-trial.md).
- **Why:** Teams need shared access. Solo dev = one-person org.
- **Trade-offs:** Extra table. Worth it for team support.

### 11.3 Time-Based Trial vs Resource-Based Limits

- **Options:** A) Resource limits (5 inboxes, 50 emails, etc.), B) Time-based trial (full access for X days)
- **Chosen:** B — Time-based trial
- **Why:** More honest — user sees the real product. Resource limits create artificial friction. Time pressure is a better conversion mechanism.
- **Trade-offs:** No long-term free tier. Acceptable — the goal is evaluation, not permanent free hosting.

### 11.4 Verification: Required vs Optional

- **Options:** A) Always require email verification, B) Only if outbound SMTP is configured
- **Chosen:** B — Conditional on SMTP configuration
- **Why:** Solo dev shouldn't need to configure Resend to use Inboxed. Graceful degradation.
- **Trade-offs:** Without SMTP, anyone can register with any email (no verification). Mitigated by: in that case, registration is typically closed or invite-only.

### 11.5 Admin Token: Keep vs Replace

- **Options:** A) Keep `INBOXED_ADMIN_TOKEN` forever, B) One-time setup token replaced by user account
- **Chosen:** B — One-time setup token. See [ADR-026](../adrs/026-cloud-authentication.md).
- **Why:** Static tokens are a security anti-pattern. Real user accounts provide audit trail, session expiry, rotation.
- **Trade-offs:** Breaking change for existing users (migration path provided).

---

## 12. Implementation Plan

### Step 1: Database & Models

1. Create migration for `settings` table
2. Create migration for `organizations` table
3. Create migration for `users` table
4. Create migration for `memberships` table
5. Create migration for `invitations` table
6. Create migration for `sessions` table
7. Create migration to add `organization_id` to `projects`
8. Create all AR models: `OrganizationRecord`, `UserRecord`, `MembershipRecord`, `InvitationRecord`
9. Create domain entities and events
10. Configure ActiveRecord session store
11. **Verify:** Migrations run, models validate, associations work

### Step 2: Setup Wizard

1. Create `Inboxed::Settings` module
2. Create `SetupController` (show + create)
3. Create `SetupInstance` application service
4. Add setup routes
5. Create dashboard `/setup` page
6. Add redirect: if setup not completed → `/setup`; if completed → `/login`
7. **Verify:** Fresh boot → `/setup` → create admin → redirected to dashboard

### Step 3: Session Auth

1. Create `Auth::SessionsController` (create, show, destroy)
2. Create `Auth::RegistrationsController`
3. Create `Auth::VerificationsController`
4. Create `Auth::PasswordsController`
5. Create application services: `RegisterUser`, `VerifyUser`, `AuthenticateUser`, `SendVerificationEmail`, `ResetPassword`
6. Add CSRF protection
7. Update admin base controller to use session auth (replace admin token)
8. **Verify:** Register → verify → login → session works → logout

### Step 4: Tenant Isolation

1. Implement `Inboxed::CurrentTenant`
2. Create `TenantScoping` middleware
3. Update all read models to use `CurrentTenant.scope_projects`
4. Update all admin controllers with `around_action :with_tenant`
5. Create tenant isolation test suite
6. **Verify:** User A cannot access Org B's data via any endpoint

### Step 5: Roles & Authorization

1. Implement `Inboxed::Authorization`
2. Create `TrialEnforced` concern
3. Add authorization checks to controllers (create, delete, manage)
4. Add trial status check to write endpoints
5. **Verify:** Member cannot invite. Trial expired cannot create. Site admin can see all.

### Step 6: Invitations

1. Create `InviteUser` application service
2. Create `Auth::InvitationsController` (show, accept)
3. Create `Admin::InvitationsController` (index, create, destroy)
4. Create `Admin::MembersController` (index, destroy)
5. Create `InvitationMailer`
6. **Verify:** Invite → email sent → click link → register → joined org

### Step 7: Outbound Email

1. Configure ActionMailer with `OUTBOUND_SMTP_*` env vars
2. Create `UserMailer` (verification, password reset)
3. Create `InvitationMailer`
4. Create email templates (plain text, minimal)
5. Add graceful degradation (auto-verify if no SMTP)
6. **Verify:** With Resend configured → verification email arrives. Without → user auto-verified.

### Step 8: GitHub OAuth

1. Add `omniauth-github` gem (or manual OAuth flow)
2. Create `Auth::OauthController`
3. Wire find-or-create user + org logic
4. **Verify:** GitHub login → user created → session → dashboard

### Step 9: Dashboard Auth Pages

1. Create `/setup` page (first boot wizard)
2. Create `/login` page (email/password + GitHub)
3. Create `/register` page (when open registration)
4. Create `/verify` page
5. Create `/forgot-password` and `/reset-password` pages
6. Create `/invitation` page (accept invite)
7. Update `authStore` with new state shape
8. Update API client for cookie auth
9. Update root layout auth guard
10. **Verify:** All auth flows work in browser

### Step 10: Dashboard Management Pages

1. Create `/settings/members` page
2. Create `/settings/invitations` page
3. Create `/settings/organization` page
4. Add trial banner component
5. Update sidebar with org name, user email, trial status
6. Add site admin pages (if site_admin): org list, user list, grant permanent
7. **Verify:** Org admin can invite, manage members, see trial status

### Step 11: Migration from Admin Token

1. Create migration script: existing projects → create org → create admin user from env
2. Document migration path in CHANGELOG
3. Deprecation notice: `INBOXED_ADMIN_TOKEN` logs a warning suggesting migration
4. **Verify:** Existing instance upgrades without data loss

### Step 12: Cleanup & Testing

1. Create `MaintenanceCleanupJob` (sessions, expired invitations, unverified users)
2. Add to recurring schedule
3. RSpec: setup wizard, registration, verification, login, password reset
4. RSpec: tenant isolation (exhaustive)
5. RSpec: authorization (every role × every action)
6. RSpec: trial enforcement (active, expired, permanent)
7. RSpec: invitation flow (invite, accept, expire, revoke)
8. Vitest: auth pages, trial banner, members page
9. Integration: setup → invite → register → verify → use → trial expires → read-only
10. `bundle exec standardrb` + `svelte-check` + `eslint` — zero errors

---

## 13. Exit Criteria

### Setup

- [ ] **EC-001:** Fresh instance redirects to `/setup`
- [ ] **EC-002:** Setup requires valid `INBOXED_SETUP_TOKEN`
- [ ] **EC-003:** Setup creates site_admin user + organization + session
- [ ] **EC-004:** Setup can only run once (subsequent visits redirect to `/login`)
- [ ] **EC-005:** After setup, `INBOXED_ADMIN_TOKEN` is no longer used for auth

### Registration & Auth

- [ ] **EC-006:** `REGISTRATION_MODE=open` allows public registration
- [ ] **EC-007:** `REGISTRATION_MODE=invite_only` requires invitation token
- [ ] **EC-008:** `REGISTRATION_MODE=closed` returns 403 on registration
- [ ] **EC-009:** Registration with SMTP configured sends verification email
- [ ] **EC-010:** Registration without SMTP auto-verifies user
- [ ] **EC-011:** Unverified user cannot login when SMTP is configured (403)
- [ ] **EC-012:** Login creates session cookie, subsequent requests authenticated
- [ ] **EC-013:** Logout destroys session
- [ ] **EC-014:** Password reset flow works end-to-end
- [ ] **EC-015:** GitHub OAuth creates user + session

### Organizations & Roles

- [ ] **EC-016:** Open registration creates org with trial (`TRIAL_DURATION_DAYS`)
- [ ] **EC-017:** `TRIAL_DURATION_DAYS=0` creates permanent org
- [ ] **EC-018:** site_admin can view and manage all organizations
- [ ] **EC-019:** org_admin can invite members and manage org settings
- [ ] **EC-020:** member can view data but cannot invite or manage
- [ ] **EC-021:** site_admin can grant permanent access (remove trial)

### Tenant Isolation

- [ ] **EC-022:** User in Org A cannot list Org B's projects
- [ ] **EC-023:** User in Org A cannot view Org B's emails
- [ ] **EC-024:** User in Org A cannot access Org B's HTTP endpoints
- [ ] **EC-025:** User in Org A cannot access Org B's API keys
- [ ] **EC-026:** site_admin can access all organizations' data
- [ ] **EC-027:** `CurrentTenant` raises if not set (fail-open impossible)
- [ ] **EC-028:** Tenant isolation test suite passes in CI

### Trial

- [ ] **EC-029:** Trial org has full access during trial period
- [ ] **EC-030:** Expired trial: read-only (can view, cannot create/send)
- [ ] **EC-031:** Expired trial: SMTP rejection (cannot send emails)
- [ ] **EC-032:** Trial banner shows days remaining
- [ ] **EC-033:** Expired banner shows "contact admin" message
- [ ] **EC-034:** Permanent org has no trial banner or restrictions

### Invitations

- [ ] **EC-035:** org_admin can create invitation with role
- [ ] **EC-036:** Invitation email sent when SMTP configured
- [ ] **EC-037:** Invitation link shows registration form pre-filled with org
- [ ] **EC-038:** Accepted invitation joins user to org with correct role
- [ ] **EC-039:** Expired invitation cannot be accepted (403)
- [ ] **EC-040:** org_admin can revoke pending invitation
- [ ] **EC-041:** Without SMTP: invitation shows copyable link in dashboard

### Outbound Email

- [ ] **EC-042:** Verification email sent via configured SMTP relay
- [ ] **EC-043:** Password reset email sent via configured SMTP relay
- [ ] **EC-044:** Invitation email sent via configured SMTP relay
- [ ] **EC-045:** Without SMTP config: users auto-verified, password reset unavailable
- [ ] **EC-046:** Dashboard shows notice when SMTP not configured

### Dashboard

- [ ] **EC-047:** Setup page renders on first boot
- [ ] **EC-048:** Login page shows email/password + optional GitHub
- [ ] **EC-049:** Register page shows when `REGISTRATION_MODE=open`
- [ ] **EC-050:** Members page lists org members with roles
- [ ] **EC-051:** Invite dialog sends invitation
- [ ] **EC-052:** Sidebar shows org name, user email, trial status
- [ ] **EC-053:** Trial banner visible when trial active
- [ ] **EC-054:** Site admin panel visible only to site_admin

### Migration

- [ ] **EC-055:** Existing instance can upgrade without data loss
- [ ] **EC-056:** Migration creates org from existing projects
- [ ] **EC-057:** `INBOXED_ADMIN_TOKEN` logs deprecation warning

### Integration

- [ ] **EC-058:** Full flow: setup → invite → register → verify → login → use → trial expires → read-only → admin grants permanent → full access
- [ ] **EC-059:** `bundle exec standardrb` passes
- [ ] **EC-060:** `svelte-check` passes
- [ ] **EC-061:** All RSpec and Vitest tests pass

---

## 14. Open Questions

1. **Multiple orgs per user?** Current design: one org per user. Should a user be able to join multiple orgs (e.g., a consultant working with multiple teams)? Recommendation: not in this spec — one org keeps it simple. Add multi-org later if requested.

2. **Org transfer?** Can a site admin transfer a project between orgs? Recommendation: yes, add a site admin action for this. Low priority — implement when needed.

3. **Billing integration (future)?** If an operator wants to charge for access, should the trial system support Stripe integration? Recommendation: out of scope. The trial is a manual approval system. If billing demand appears, it's a separate spec.

4. **LDAP/SAML?** Enterprise auth protocols. Recommendation: not in this spec. If enterprise users need it, add an auth adapter layer later. The session mechanism supports swapping the auth backend.

5. **Audit log?** Should the system log who did what (created project, invited user, etc.)? Recommendation: the event store already captures domain events. Add a UI for viewing them in a future spec. The data is there.
