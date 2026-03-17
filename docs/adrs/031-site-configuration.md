# ADR-031: Site Configuration / Global Settings

**Status:** proposed
**Date:** 2026-03-17
**Deciders:** Project owner
**Panel consulted:** Full-Stack Engineer, Security Engineer, DevOps Engineer, API Design Architect, Product Manager, UX/UI Designer

## Context

Inboxed currently manages configuration through environment variables (`.env`). This works for initial setup but has problems:

1. **Changing a setting requires restart** — editing `.env` and restarting containers
2. **No admin UI** — the operator must SSH into the server or edit files
3. **Feature flags are static** — `INBOXED_FEATURE_*` env vars can't be toggled at runtime
4. **No per-project overrides** — some settings (like `inbound_email`) should be toggleable per project by an admin
5. **Growing env var sprawl** — as features grow, `.env.example` becomes unwieldy

### What to Move to Site Config

Settings that an admin should be able to change at runtime without restart:

| Setting | Current Source | Proposed |
|---------|---------------|----------|
| Feature flags (hooks, forms, heartbeats, inbound_email) | `INBOXED_FEATURE_*` env vars | Site config (global) + project override |
| Registration mode | `REGISTRATION_MODE` env var | Site config |
| Trial duration | `TRIAL_DURATION_DAYS` env var | Site config |
| Email TTL | `EMAIL_TTL_HOURS` env var | Site config (global default) |
| Max emails per project | `INBOXED_MAX_EMAILS_PER_PROJECT` env var | Site config |
| Max message size | `INBOXED_MAX_MESSAGE_SIZE_MB` env var | Site config |
| Rate limits | `RATE_LIMIT_*` env vars | Site config |

### What Stays as Env Vars

Settings that are infrastructure-level and MUST be set before boot:

- `SECRET_KEY_BASE`, `DATABASE_URL`, `REDIS_URL` — framework requirements
- `SMTP_HOST`, `SMTP_PORTS`, `SMTP_TLS_*` — SMTP server bind config
- `INBOUND_WEBHOOK_SECRET` — security credential
- `POSTGRES_PASSWORD` — database credential
- `INBOXED_DOMAIN`, `INBOXED_BASE_URL`, `DASHBOARD_URL` — URLs (used at boot)

### Options Considered

**A: YAML file on disk**
- Pro: Simple, version-controllable
- Con: Requires restart to pick up changes
- Con: No admin UI without building a file editor
- Con: Docker volume management for config files

**B: Redis-backed**
- Pro: Fast reads, pub/sub for cache invalidation
- Con: Adds Redis as a hard dependency for config (currently only used for ActionCable)
- Con: Not queryable, no audit trail
- Con: Overkill for a settings store with <50 keys

**C: PostgreSQL `settings` table**
- Pro: Already have PG, zero new dependencies
- Pro: Queryable, auditable, persistent
- Pro: Transactional — settings changes are atomic
- Pro: Standard ActiveRecord patterns apply
- Con: Slightly slower than Redis for reads (mitigated by in-memory cache)

**D: Keep env vars (status quo)**
- Pro: No code change
- Con: Requires restart for every change
- Con: No admin UI
- Con: No per-project overrides

## Decision

**Option C** — PostgreSQL-backed site configuration with in-memory cache (class-level cache with 30-second TTL).

### Expert Panel Input

**Full-Stack Engineer:**
> "A single `settings` table with `key/value/type` columns is the simplest approach. Use a class-level cache with a short TTL (30 seconds) so you're not hitting the DB on every request. The cache invalidation is simple — just let it expire. For the dashboard, a Settings page with grouped sections (General, Features, Limits, Security). Don't over-engineer this with a full CMS — it's a dev tool admin panel."

**Security Engineer:**
> "Settings must be admin-only. The API endpoint should use admin token auth (same as existing admin routes). Never expose settings to regular API key auth — feature flags and rate limits are operator decisions, not tenant decisions. The per-project overrides are fine but only settable by admin. Also: env vars should take precedence as final override — if the operator sets `INBOXED_FEATURE_INBOUND_EMAIL=false` in the env, the DB setting cannot override it. This is a safety valve."

**DevOps Engineer:**
> "The resolution order should be: env var (if set) → project setting (if exists) → site config (DB) → hardcoded default. This means self-hosters who prefer env vars can keep using them, and the DB settings are an optional layer. The `bin/setup` script should seed default settings on first run. Docker Compose users shouldn't have to touch the dashboard to get reasonable defaults."

**API Design Architect:**
> "The admin settings API should be flat and simple: `GET /admin/settings` returns all, `PATCH /admin/settings` accepts a partial update. Don't make it a CRUD resource per setting — that's overengineered. Group settings in the response by category for the dashboard. Per-project feature flags go through `PATCH /admin/projects/:id/settings`."

**Product Manager:**
> "This unlocks a lot. Right now adding a feature flag means telling users to edit .env and restart. With site config, the admin toggles it in the dashboard. The settings page is also the first thing a new admin sees after setup — make it clear and well-organized. Categories: General, Features, Limits, Email, Security."

**UX/UI Designer:**
> "The settings page should follow a two-column layout: labels on the left, inputs on the right, grouped by category with section headers. Use toggle switches for booleans (feature flags), number inputs for limits, and dropdowns for enums (registration_mode). Show the current effective value and where it comes from (env var override, DB, default) as subtle hint text. If an env var overrides a DB setting, show the input as disabled with a tooltip: 'Overridden by environment variable'."

## Schema

### `settings` table

```ruby
create_table :settings, id: :uuid do |t|
  t.string  :key,        null: false
  t.string  :value                     # stored as string, cast by type
  t.string  :value_type, null: false, default: "string"  # string, integer, boolean, json
  t.string  :category,   null: false, default: "general"
  t.string  :description
  t.timestamps
end

add_index :settings, :key, unique: true
add_index :settings, :category
```

### `project_settings` table (per-project overrides)

```ruby
create_table :project_settings, id: :uuid do |t|
  t.references :project, type: :uuid, null: false, foreign_key: true
  t.string  :key,        null: false
  t.string  :value
  t.string  :value_type, null: false, default: "string"
  t.timestamps
end

add_index :project_settings, [:project_id, :key], unique: true
```

## Resolution Order

```
ENV var (if set) → Project setting → Site setting (DB) → Hardcoded default
```

ENV vars are the ultimate override — the operator can always force a value via environment. This means:

1. If `ENV["INBOXED_FEATURE_INBOUND_EMAIL"]` is set, that value wins regardless of what's in the DB
2. If a project has a `project_settings` row for `feature_inbound_email`, that overrides the global site setting for that project
3. If the `settings` table has a row for `feature_inbound_email`, that's the global default
4. If nothing is set anywhere, the hardcoded default applies (`false` for inbound email)

This layered approach means self-hosters who prefer env vars can keep using them. The DB settings are an optional convenience layer accessible through the admin UI.

## Consequences

### Easier

- **Runtime config changes** — toggle feature flags, adjust rate limits, change registration mode without restarting containers
- **Admin UI** — settings page in the dashboard, no SSH required
- **Per-project overrides** — enable inbound email for one project without affecting others
- **No restarts** — cache TTL of 30s means changes take effect within half a minute
- **Backward compatible** — env vars still work and take precedence, existing deployments are unaffected

### Harder

- **Two sources of truth** — settings can come from env vars or DB, which can be confusing when debugging
- **Cache invalidation** — 30s TTL means there's a window where stale settings are served (acceptable for a dev tool)
- **Migration to seed defaults** — `bin/setup` and `db:seed` must populate initial settings
- **Testing complexity** — tests need to account for both env var and DB settings sources
- **Documentation** — configuration guide must explain the resolution order clearly

### Mitigations

- The settings API response includes `source` field (env, db, default) so it's always clear where a value comes from
- The dashboard shows override indicators when an env var is active
- Default seed values match current `.env.example` defaults — zero behavior change on upgrade
- Test helpers can stub the settings cache directly
