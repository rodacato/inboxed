# ADR-027: Tenant Isolation — Row-Level Scoping with Test Verification

**Status:** accepted
**Date:** 2026-03-16
**Deciders:** Project owner
**Panel consulted:** Security Engineer, Database Engineer, Full-Stack Engineer

## Context

Cloud mode introduces multi-tenancy — multiple users, each with their own projects. The most critical security requirement is that no user can ever access another user's data. A single cross-tenant data leak would destroy trust in the product.

Inboxed already has a natural isolation boundary: `project_id` on every resource (inboxes, emails, attachments, webhook endpoints, HTTP requests, events). In standalone mode this is organizational; in cloud mode it becomes a hard security boundary.

### Tenancy Hierarchy

```
User
  └── Project (via users_projects join)
        ├── Inbox → Emails → Attachments
        ├── HttpEndpoint → HttpRequests
        ├── WebhookEndpoint → WebhookDeliveries
        ├── ApiKeys
        └── Events
```

### Options Considered

**A: Row-level scoping in application layer (current project_id pattern)**
- Pro: Already partially implemented — every table has `project_id`
- Pro: Simple — add `where(project_id:)` to every query
- Pro: One database, no per-tenant overhead
- Con: A single missed scope leaks data across tenants
- Con: Requires discipline and testing to maintain

**B: PostgreSQL Row-Level Security (RLS)**
- Pro: Database enforces isolation — even raw SQL can't bypass it
- Pro: Defense in depth — application bugs can't leak tenant data
- Con: Complexity — RLS policies, session variables (`SET app.current_project_id`), connection pool interaction
- Con: Harder to debug — queries silently return empty sets if policy is wrong
- Con: Testing is complex — need to verify RLS policies themselves
- Con: Overkill for a single-VPS tool with < 1000 users

**C: Schema-per-tenant**
- Pro: Complete isolation at database level
- Con: Enormous operational overhead (migrations per tenant, connection management)
- Con: Completely inappropriate for the expected scale

## Decision

**Option A** — application-level row scoping via `project_id`, with **mandatory tenant isolation tests** that verify every query is scoped.

### Why Not RLS?

RLS is the gold standard for multi-tenant isolation, but it adds significant complexity to a solo-developer project running on a single VPS. The expected cloud scale (< 1000 users, < 5000 projects) doesn't justify the operational overhead.

Instead, we achieve equivalent safety through:
1. A `CurrentTenant` context object that wraps every query
2. A test suite that **exhaustively verifies** no query can access cross-tenant data
3. A middleware that sets the tenant context per-request

If Inboxed Cloud ever scales beyond a single VPS, RLS can be added as a defense-in-depth layer without changing application code.

### Implementation

#### Tenant Context

```ruby
# lib/inboxed/current_tenant.rb
module Inboxed
  class CurrentTenant
    thread_mattr_accessor :project_ids

    def self.set(project_ids:)
      self.project_ids = Array(project_ids)
      yield
    ensure
      self.project_ids = nil
    end

    def self.scope(relation)
      raise "CurrentTenant not set" if project_ids.nil?
      relation.where(project_id: project_ids)
    end

    def self.set?
      project_ids.present?
    end
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

    if cloud_mode?
      user = authenticate_user(request)
      if user
        project_ids = user.projects.pluck(:id)
        Inboxed::CurrentTenant.set(project_ids: project_ids) do
          @app.call(env)
        end
      else
        @app.call(env)  # Unauthenticated — controller will reject
      end
    else
      # Standalone: no tenant scoping, all projects accessible
      @app.call(env)
    end
  end
end
```

#### Scoped Queries

In cloud mode, every read model and repository uses `CurrentTenant.scope`:

```ruby
# Example: scoped project list
module Inboxed::ReadModels
  class ProjectList
    def self.call(...)
      scope = ProjectRecord.all
      scope = Inboxed::CurrentTenant.scope(scope) if Inboxed::CurrentTenant.set?
      # ... pagination, ordering
    end
  end
end
```

For controllers that already scope by `current_project`, the project lookup itself is scoped:

```ruby
# In cloud mode, current_project is verified against user's projects
def current_project
  if cloud_mode?
    Inboxed::CurrentTenant.scope(ProjectRecord).find(params[:project_id])
  else
    ProjectRecord.find(params[:project_id])
  end
end
```

#### Limit Enforcement

```ruby
# lib/inboxed/cloud_limits.rb
module Inboxed
  class CloudLimits
    LIMITS = {
      projects_per_user: 1,
      inboxes_per_project: 5,
      emails_retained: 50,
      webhook_endpoints: 2,
      http_endpoints_per_type: { webhook: 2, form: 2, heartbeat: 2 },
      requests_per_endpoint: 20,
      ttl_hours: 1,
      api_rate_limit: 60,    # requests/minute
      smtp_rate_limit: 10,   # emails/hour
      max_email_body: 100_000,  # 100KB
      max_webhook_body: 262_144  # 256KB
    }.freeze

    def self.check!(resource, user:, project: nil)
      return unless cloud_mode?

      case resource
      when :project
        current = user.projects.count
        raise LimitExceeded.new(:projects, current, LIMITS[:projects_per_user]) if current >= LIMITS[:projects_per_user]
      when :inbox
        current = project.inboxes.count
        raise LimitExceeded.new(:inboxes, current, LIMITS[:inboxes_per_project]) if current >= LIMITS[:inboxes_per_project]
      # ... other limits
      end
    end

    class LimitExceeded < StandardError
      attr_reader :resource, :current, :limit

      def initialize(resource, current, limit)
        @resource = resource
        @current = current
        @limit = limit
        super("Limit exceeded: #{resource} (#{current}/#{limit}). Self-host for unlimited: https://github.com/your/inboxed")
      end
    end
  end
end
```

### Tenant Isolation Test Suite

The most important part of this decision. A dedicated test file that verifies cross-tenant isolation for every queryable resource:

```ruby
# spec/security/tenant_isolation_spec.rb
RSpec.describe "Tenant Isolation", :cloud do
  let(:user_a) { create(:user, :verified) }
  let(:user_b) { create(:user, :verified) }
  let(:project_a) { create(:project, user: user_a) }
  let(:project_b) { create(:project, user: user_b) }

  before do
    # Create resources for both tenants
    @inbox_a = create(:inbox, project: project_a)
    @inbox_b = create(:inbox, project: project_b)
    @email_a = create(:email, inbox: @inbox_a)
    @email_b = create(:email, inbox: @inbox_b)
    @endpoint_a = create(:http_endpoint, project: project_a)
    @endpoint_b = create(:http_endpoint, project: project_b)
  end

  context "User A cannot access User B's data" do
    before { sign_in(user_a) }

    it "cannot list User B's projects" do
      get "/admin/projects"
      expect(json_ids).to include(project_a.id)
      expect(json_ids).not_to include(project_b.id)
    end

    it "cannot view User B's project" do
      get "/admin/projects/#{project_b.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot list User B's inboxes" do
      get "/admin/projects/#{project_b.id}/inboxes"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot view User B's emails" do
      get "/admin/projects/#{project_b.id}/emails/#{@email_b.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "cannot view User B's HTTP endpoints" do
      get "/admin/endpoints?project_id=#{project_b.id}"
      expect(json_ids).to be_empty
    end

    # ... exhaustive tests for every resource type
  end
end
```

This test suite is **mandatory** — it runs in CI on every commit and must pass before any merge to main.

## Consequences

### Easier

- **No infrastructure changes** — same database, same connection pool, same queries (just scoped)
- **Standalone unaffected** — zero multi-tenant code paths when `INBOXED_MODE=standalone`
- **Familiar pattern** — `where(project_id:)` is standard Rails multi-tenancy
- **Testable** — cross-tenant tests are simple to write and understand

### Harder

- **Developer discipline** — every new query must include tenant scoping
- **No database-level guarantee** — a missed scope leaks data (mitigated by exhaustive tests)

### Mitigations

- `CurrentTenant` context raises if not set in cloud mode — fail-open is impossible
- Tenant isolation test suite is exhaustive and runs on every CI build
- Read models are the query layer — centralizing scoping there covers most cases
- Code review checklist includes "is this query tenant-scoped?"
- If needed later, RLS can be added as defense-in-depth without application changes
