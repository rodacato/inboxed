# ADR-029: Organizations, Roles & Time-Based Trial

**Status:** accepted
**Date:** 2026-03-16
**Deciders:** Project owner
**Panel consulted:** Product Manager, Security Engineer, Full-Stack Engineer, API Design Architect

## Context

Inboxed needs a tenancy model that supports three deployment scenarios with one codebase:

| Scenario | Who registers | Trial? | Example |
|---|---|---|---|
| **Solo developer** | Admin via setup wizard | No | localhost, personal VPS |
| **Team** | Admin invites members | No | Company VPS, shared staging |
| **Public instance** | Anyone registers | Yes, time-limited | `cloud.inboxed.dev` or any operator's public instance |

Rather than separate modes, these are different **configurations** of the same system: registration policy (open vs invite-only) and trial duration.

### Options Considered

**A: User-level tenancy (users own projects directly)**
- Pro: Simpler — no organization concept
- Con: No way to share projects between team members
- Con: "Solo dev" and "team" are fundamentally different models
- Con: Adding teams later requires a migration that touches every project

**B: Organization-level tenancy (orgs own projects, users belong to orgs)**
- Pro: Natural grouping — a team is an org, a solo dev is a one-person org
- Pro: Sharing is built in — invite users to the org
- Pro: The tenant boundary (org) is separate from the user identity
- Con: Extra table and join, slightly more complex

**C: Organization + Team sub-groups**
- Pro: Fine-grained access (Team A sees Project A, Team B sees Project B)
- Con: Over-engineered — Inboxed is a dev tool, not an enterprise IAM system
- Con: Adds complexity without clear value at this scale

## Decision

**Option B** — Organization as the tenant, with roles and optional time-based trial.

### Data Model

```sql
CREATE TABLE organizations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            VARCHAR NOT NULL,
  slug            VARCHAR NOT NULL,
  trial_ends_at   TIMESTAMPTZ,           -- NULL = no trial (permanent access)
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT organizations_slug_unique UNIQUE (slug)
);

CREATE TABLE memberships (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  role            VARCHAR NOT NULL DEFAULT 'member',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT memberships_unique UNIQUE (user_id, organization_id),
  CONSTRAINT memberships_role_check CHECK (role IN ('org_admin', 'member'))
);

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

  CONSTRAINT invitations_token_unique UNIQUE (token),
  CONSTRAINT invitations_role_check CHECK (role IN ('org_admin', 'member'))
);

CREATE INDEX idx_invitations_token ON invitations(token);
CREATE INDEX idx_invitations_email ON invitations(email);

-- Add organization_id to projects
ALTER TABLE projects ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;
CREATE INDEX idx_projects_organization ON projects(organization_id);

-- Add site_admin flag to users
ALTER TABLE users ADD COLUMN site_admin BOOLEAN DEFAULT false;
```

### Roles

Three-level role model:

| Role | Scope | Can do |
|---|---|---|
| **site_admin** | Entire instance | Everything. Manage all orgs, users, settings. Created during setup. |
| **org_admin** | One organization | Manage projects, invite/remove members, manage API keys, view all data in org |
| **member** | One organization | View projects and data, use API keys. Cannot invite or manage settings. |

`site_admin` is a flag on the user, not a membership role. A site admin can also be a member of specific orgs.

### Organizations

- Every user belongs to exactly one organization (via membership)
- Solo developers are a one-person org (auto-created at registration)
- Teams are multi-person orgs (admin invites members)
- The site admin's org is created during setup

### Trial System

Trial is **time-based** on the organization, not resource-based:

```ruby
class OrganizationRecord < ApplicationRecord
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
end
```

#### Trial behavior:

| State | Access | Dashboard shows |
|---|---|---|
| **Permanent** (`trial_ends_at = NULL`) | Full access, no restrictions | Nothing — normal usage |
| **Trial active** | Full access, all features | "Trial: X days remaining. Contact admin for permanent access." |
| **Trial expired** | Read-only. Can view data but not create/send. | "Trial expired. Contact the administrator to continue using Inboxed." |

Key design decisions:
- **Full access during trial** — no artificial resource limits. The user sees the real product.
- **Read-only on expiry** — not locked out completely. They can still view their data and export.
- **Admin grants permanent access** — sets `trial_ends_at = NULL` on the org. No payment, no plan upgrade.

#### Trial configuration:

```bash
# Instance-level settings (env vars)
REGISTRATION_MODE=open          # 'open' | 'invite_only' | 'closed'
TRIAL_DURATION_DAYS=7           # 0 = no trial (permanent immediately)
```

When `REGISTRATION_MODE=open`:
- Anyone can register
- New org gets `trial_ends_at = NOW() + TRIAL_DURATION_DAYS`
- If `TRIAL_DURATION_DAYS=0`, org is permanent immediately

When `REGISTRATION_MODE=invite_only`:
- Only invited users can register (invitation token required)
- Invited users join existing org (no trial — admin already approved them)

When `REGISTRATION_MODE=closed`:
- Registration disabled. Only site admin can create users.

### Invitations

```ruby
# Org admin invites a user
invitation = Invitation.create!(
  organization: current_org,
  email: "dev@example.com",
  role: "member",
  token: SecureRandom.urlsafe_base64(32),
  invited_by: current_user,
  expires_at: 7.days.from_now
)

# System sends invitation email (via outbound SMTP)
InvitationMailer.invite(invitation).deliver_later

# Invitee clicks link → /auth/accept-invitation?token=xxx
# → Creates account (or links existing) → joins org with assigned role
```

### Project Ownership

Projects belong to organizations, not users:

```ruby
# Before (spec 011):
# User → Project (via users_projects)

# After:
# Organization → Project
# User → Organization (via membership)
# User accesses projects through their org membership
```

This means all org members can see all org projects. There's no per-project permission — the org is the access boundary. This is intentionally simple.

## Consequences

### Easier

- **One model for all scenarios** — solo dev = 1-person org, team = multi-person org, public = open registration with trial
- **No mode flag** — configuration via env vars, not code branches
- **Natural sharing** — invite to org, instant access to all projects
- **Simple trial** — time-based, full access, no artificial limits
- **Clean tenant boundary** — org_id on projects, scoped everywhere

### Harder

- **Extra tables** — organizations, memberships, invitations (3 tables vs spec 011's 2)
- **Invitation flow** — email sending, token validation, acceptance
- **Trial expiry** — need to handle read-only mode gracefully in UI and API

### Mitigations

- Extra tables are simple and well-understood (standard SaaS pattern)
- Invitation flow reuses the same email infrastructure as verification
- Trial expiry is a single `before_action` check in controllers
- Read-only mode is a UI concern — API returns 403 with clear message
