# ADR-027: Tenant Isolation — Organization-Scoped Row-Level Filtering

> **Updated 2026-03-16:** Rewritten to use Organization as the tenant boundary (not User directly). Removed `INBOXED_MODE` conditionals — tenant scoping is always active.

**Status:** accepted
**Date:** 2026-03-16
**Deciders:** Project owner
**Panel consulted:** Security Engineer, Database Engineer, Full-Stack Engineer

## Context

Inboxed is always multi-user. Organizations are the tenant boundary — each org has its own projects, users, and data. The most critical security requirement is that no user can access another organization's data.

### Tenancy Hierarchy

```
Organization
  ├── Users (via memberships, with roles)
  └── Projects
        ├── Inbox → Emails → Attachments
        ├── HttpEndpoint → HttpRequests
        ├── WebhookEndpoint → WebhookDeliveries
        ├── ApiKeys
        └── Events
```

A user belongs to one organization (via membership). A site admin can see all organizations.

### Options Considered

**A: Row-level scoping in application layer (organization_id on projects)**
- Pro: Projects already have an owner — adding `organization_id` is natural
- Pro: Simple — `where(organization_id:)` on every query
- Pro: One database, no per-tenant overhead
- Con: A single missed scope leaks data across tenants
- Con: Requires discipline and testing

**B: PostgreSQL Row-Level Security (RLS)**
- Pro: Database enforces isolation — even raw SQL can't bypass it
- Con: Complexity — RLS policies, session variables, connection pool interaction
- Con: Harder to debug — queries silently return empty sets if policy is wrong
- Con: Overkill for expected scale (< 1000 orgs)

**C: Schema-per-tenant**
- Pro: Complete isolation
- Con: Enormous operational overhead — inappropriate for this scale

## Decision

**Option A** — application-level row scoping via `organization_id` on projects, with **mandatory tenant isolation tests**.

### Implementation

#### Tenant Context

Always active — no mode check:

```ruby
# lib/inboxed/current_tenant.rb
module Inboxed
  class CurrentTenant
    thread_mattr_accessor :organization_id, :user_id, :role

    def self.set(user:, organization:)
      self.user_id = user.id
      self.organization_id = organization.id
      self.role = user.role_in(organization)
      yield
    ensure
      self.user_id = nil
      self.organization_id = nil
      self.role = nil
    end

    def self.scope_projects(relation)
      if site_admin?
        relation  # Site admins see everything
      else
        raise TenantNotSet, "CurrentTenant not set" unless set?
        relation.where(organization_id: organization_id)
      end
    end

    def self.set?
      organization_id.present?
    end

    def self.site_admin?
      role == "site_admin"
    end

    def self.org_admin?
      role.in?(%w[site_admin org_admin])
    end

    class TenantNotSet < StandardError; end
  end
end
```

#### Middleware

```ruby
# app/middleware/tenant_scoping.rb
class TenantScoping
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    user = resolve_user(request)

    if user
      organization = user.organization
      Inboxed::CurrentTenant.set(user: user, organization: organization) do
        @app.call(env)
      end
    else
      @app.call(env)  # Unauthenticated — controller auth will reject
    end
  end

  private

  def resolve_user(request)
    # From session (dashboard)
    if (user_id = request.session[:user_id])
      UserRecord.find_by(id: user_id)
    end
  end
end
```

#### Scoped Queries

Every read model scopes through `CurrentTenant`:

```ruby
# All project queries go through this
module Inboxed::ReadModels
  class ProjectList
    def self.call(**params)
      scope = Inboxed::CurrentTenant.scope_projects(ProjectRecord.all)
      scope.order(created_at: :desc)
    end
  end
end
```

For resources under a project, the project lookup is already scoped:

```ruby
def current_project
  Inboxed::CurrentTenant.scope_projects(ProjectRecord).find(params[:project_id])
end
# If the project doesn't belong to the user's org → RecordNotFound → 404
```

#### Tenant Isolation Test Suite

Mandatory, exhaustive, runs on every CI build:

```ruby
# spec/security/tenant_isolation_spec.rb
RSpec.describe "Tenant Isolation" do
  let(:org_a) { create(:organization) }
  let(:org_b) { create(:organization) }
  let(:user_a) { create(:user, organization: org_a) }
  let(:user_b) { create(:user, organization: org_b) }
  let(:project_a) { create(:project, organization: org_a) }
  let(:project_b) { create(:project, organization: org_b) }

  before do
    @inbox_a = create(:inbox, project: project_a)
    @inbox_b = create(:inbox, project: project_b)
    @email_a = create(:email, inbox: @inbox_a)
    @email_b = create(:email, inbox: @inbox_b)
    @endpoint_a = create(:http_endpoint, project: project_a)
    @endpoint_b = create(:http_endpoint, project: project_b)
  end

  context "User A cannot access Org B's data" do
    before { sign_in(user_a) }

    it "cannot list Org B's projects" do
      get "/admin/projects"
      expect(json_ids).to include(project_a.id)
      expect(json_ids).not_to include(project_b.id)
    end

    it "cannot view Org B's project" do
      get "/admin/projects/#{project_b.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot list Org B's inboxes" do
      get "/admin/projects/#{project_b.id}/inboxes"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot view Org B's emails" do
      get "/admin/projects/#{project_b.id}/emails/#{@email_b.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot access Org B's HTTP endpoints" do
      get "/api/v1/endpoints/#{@endpoint_b.token}"
      expect(response).to have_http_status(:not_found)
    end

    # ... exhaustive for every resource type
  end

  context "Site admin can access all organizations" do
    let(:site_admin) { create(:user, :site_admin) }
    before { sign_in(site_admin) }

    it "can list all projects" do
      get "/admin/projects"
      expect(json_ids).to include(project_a.id, project_b.id)
    end
  end
end
```

## Consequences

### Easier

- **No infrastructure changes** — same database, same queries (just scoped)
- **No mode conditionals** — scoping is always active
- **Familiar pattern** — `where(organization_id:)` is standard Rails multi-tenancy
- **Site admin escape hatch** — admins can see everything for debugging

### Harder

- **Developer discipline** — every new query must use `CurrentTenant.scope_projects`
- **No database-level guarantee** — mitigated by exhaustive test suite

### Mitigations

- `CurrentTenant` raises `TenantNotSet` if accessed without being set
- Tenant isolation test suite runs on every CI build
- Read models centralize query scoping
- Code review checklist: "is this query tenant-scoped?"
