# 013 — Site Configuration

> Runtime site configuration without restarts. Admin UI, per-project overrides, and a layered resolution system that keeps env vars as the ultimate override.

**Phase:** Phase 7 — Post-MVP
**Status:** proposed
**Release:** —
**Depends on:** [003 — REST API](003-rest-api.md) (admin API patterns), [004 — Dashboard](004-dashboard.md) (admin UI), [011 — Cloud Free Tier](011-cloud-free-tier.md) (multi-tenancy context)
**ADRs:** [ADR-031 Site Configuration](../adrs/031-site-configuration.md)
**Expert panel:** Full-Stack Engineer + Security Engineer + DevOps Engineer + API Design Architect + Product Manager + UX/UI Designer

---

## 1. Objective

Enable Inboxed operators to change runtime configuration (feature flags, rate limits, registration mode, email retention) through the admin dashboard or API — without editing `.env` files, without restarting containers, and without SSH access.

**Use cases:**
- Admin toggles `feature_inbound_email` on for a specific project from the dashboard
- Admin changes `registration_mode` from `closed` to `open` after setting up a public instance
- Admin raises `max_emails_per_project` for a high-volume project without affecting others
- Admin adjusts `rate_limit_api` during a load test, reverts it afterward
- Self-hoster keeps using env vars exclusively — site config is an optional layer, not a replacement

## 2. Current State

- All configuration lives in environment variables (`.env` file)
- Changing any setting requires editing `.env` and restarting containers (`docker compose restart`)
- Feature flags (`INBOXED_FEATURE_*`) are read once at boot via `ENV.fetch`
- No admin settings page in the dashboard
- No per-project configuration overrides
- `.env.example` has ~40 variables and growing
- The admin API (`/admin/*`) exists with token auth but has no settings endpoints

## 3. What This Spec Delivers

### 3.1 Settings Table (PostgreSQL)

A `settings` table with key/value pairs, typed values, and category grouping. Stores all runtime-configurable settings.

### 3.2 Project Settings Table

A `project_settings` table for per-project overrides. Initially scoped to feature flags, extensible to any setting.

### 3.3 Settings Cache Layer

Class-level in-memory cache with 30-second TTL. Prevents database queries on every request while keeping settings reasonably fresh.

### 3.4 Resolution Logic

Four-layer resolution: ENV var (if set) → project setting (if exists) → site setting (DB) → hardcoded default.

### 3.5 Admin API Endpoints

`GET /admin/settings`, `PATCH /admin/settings` for global settings. `GET /admin/projects/:id/settings`, `PATCH /admin/projects/:id/settings` for project overrides.

### 3.6 Dashboard Settings Page

Admin settings page with grouped sections, toggle switches for booleans, number inputs for limits, dropdowns for enums, and env var override indicators.

### 3.7 Seed Data

Default settings seeded on first run via `db:seed` and `bin/setup`.

---

## 4. Data Model

### 4.1 `settings`

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `key` | String | Setting identifier (unique, e.g., `registration_mode`) |
| `value` | String | Stored as string, cast by `value_type` |
| `value_type` | String | `string`, `integer`, `boolean`, `json` |
| `category` | String | Grouping: `general`, `features`, `limits`, `email`, `security` |
| `description` | String | Human-readable description for the admin UI |
| `created_at` | DateTime | — |
| `updated_at` | DateTime | — |

**Indexes:** `(key)` unique, `(category)`

### 4.2 `project_settings`

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `project_id` | UUID | FK to projects |
| `key` | String | Setting identifier (e.g., `feature_inbound_email`) |
| `value` | String | Stored as string, cast by `value_type` |
| `value_type` | String | `string`, `integer`, `boolean` |
| `created_at` | DateTime | — |
| `updated_at` | DateTime | — |

**Indexes:** `(project_id, key)` unique

### 4.3 Domain Layer

```ruby
# app/domain/entities/setting.rb
module Inboxed
  module Entities
    class Setting < Dry::Struct
      attribute :id, Types::UUID
      attribute :key, Types::String
      attribute :value, Types::String.optional
      attribute :value_type, Types::String.enum("string", "integer", "boolean", "json")
      attribute :category, Types::String.enum("general", "features", "limits", "email", "security")
      attribute :description, Types::String.optional
    end
  end
end

# app/domain/entities/project_setting.rb
module Inboxed
  module Entities
    class ProjectSetting < Dry::Struct
      attribute :id, Types::UUID
      attribute :project_id, Types::UUID
      attribute :key, Types::String
      attribute :value, Types::String.optional
      attribute :value_type, Types::String.enum("string", "integer", "boolean")
    end
  end
end
```

### 4.4 ActiveRecord Models

```ruby
# app/models/setting_record.rb
class SettingRecord < ApplicationRecord
  self.table_name = "settings"

  validates :key, presence: true, uniqueness: true
  validates :value_type, inclusion: { in: %w[string integer boolean json] }
  validates :category, inclusion: { in: %w[general features limits email security] }

  scope :by_category, ->(cat) { where(category: cat) }
end

# app/models/project_setting_record.rb
class ProjectSettingRecord < ApplicationRecord
  self.table_name = "project_settings"

  belongs_to :project, class_name: "ProjectRecord"

  validates :key, presence: true, uniqueness: { scope: :project_id }
  validates :value_type, inclusion: { in: %w[string integer boolean] }
end
```

### 4.5 Migrations

```ruby
# db/migrate/xxx_create_settings.rb
class CreateSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :settings, id: :uuid do |t|
      t.string  :key,        null: false
      t.string  :value
      t.string  :value_type, null: false, default: "string"
      t.string  :category,   null: false, default: "general"
      t.string  :description
      t.timestamps
    end

    add_index :settings, :key, unique: true
    add_index :settings, :category
  end
end

# db/migrate/xxx_create_project_settings.rb
class CreateProjectSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :project_settings, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string  :key,        null: false
      t.string  :value
      t.string  :value_type, null: false, default: "string"
      t.timestamps
    end

    add_index :project_settings, [:project_id, :key], unique: true
  end
end
```

---

## 5. Settings Registry

Complete list of all settings that move from env vars to the site configuration database. Every setting has a hardcoded default that matches the current `.env.example` value — upgrading to site config changes nothing unless the admin explicitly modifies a value.

| Key | Type | Default | Category | Env Var Override | Description |
|-----|------|---------|----------|-----------------|-------------|
| `registration_mode` | string | `"closed"` | general | `REGISTRATION_MODE` | Registration policy: `open`, `invite_only`, `closed` |
| `trial_duration_days` | integer | `7` | general | `TRIAL_DURATION_DAYS` | Trial duration in days for new organizations (0 = permanent immediately) |
| `email_ttl_hours` | integer | `168` | email | `EMAIL_TTL_HOURS` | Default email retention in hours (168 = 7 days) |
| `max_emails_per_project` | integer | `10000` | limits | `INBOXED_MAX_EMAILS_PER_PROJECT` | Maximum stored emails per project before oldest are purged |
| `max_message_size_mb` | integer | `3` | limits | `INBOXED_MAX_MESSAGE_SIZE_MB` | Maximum email message size in megabytes |
| `max_inbox_count` | integer | `100` | limits | `INBOXED_MAX_INBOX_COUNT` | Maximum inboxes per project |
| `feature_hooks` | boolean | `true` | features | `INBOXED_FEATURE_HOOKS` | Enable webhook delivery for email events |
| `feature_forms` | boolean | `true` | features | `INBOXED_FEATURE_FORMS` | Enable form capture endpoints |
| `feature_heartbeats` | boolean | `true` | features | `INBOXED_FEATURE_HEARTBEATS` | Enable heartbeat monitoring |
| `feature_inbound_email` | boolean | `false` | features | `INBOXED_FEATURE_INBOUND_EMAIL` | Enable inbound email content (see ADR-030) |
| `rate_limit_api` | integer | `300` | security | `RATE_LIMIT_API` | API requests allowed per rate limit period |
| `rate_limit_auth` | integer | `5` | security | `RATE_LIMIT_AUTH` | Authentication attempts allowed per rate limit period |

### Per-Project Overridable Settings

Not all settings can be overridden per project. Only settings where per-project granularity makes sense:

| Key | Overridable? | Rationale |
|-----|-------------|-----------|
| `feature_hooks` | Yes | Admin may enable hooks for one project only |
| `feature_forms` | Yes | Admin may enable forms for one project only |
| `feature_heartbeats` | Yes | Admin may enable heartbeats for one project only |
| `feature_inbound_email` | Yes | Admin may enable inbound for specific projects (see ADR-030) |
| `email_ttl_hours` | Yes | Some projects may need longer retention |
| `max_emails_per_project` | Yes | High-volume project may need a higher limit |
| `max_inbox_count` | Yes | Some projects may need more inboxes |
| `registration_mode` | No | Instance-level only |
| `trial_duration_days` | No | Instance-level only |
| `max_message_size_mb` | No | Instance-level only (affects SMTP server) |
| `rate_limit_api` | No | Instance-level only (Rack::Attack is global) |
| `rate_limit_auth` | No | Instance-level only |

---

## 6. Resolution Logic

### 6.1 Resolution Order

```
ENV var (if set) → Project setting (if exists) → Site setting (DB) → Hardcoded default
```

- **ENV var** is the ultimate override. If the operator sets `INBOXED_FEATURE_INBOUND_EMAIL=false` in the environment, no DB setting can override it. This is a safety valve.
- **Project setting** allows per-project customization for overridable settings.
- **Site setting** is the global default stored in the DB, editable via admin UI.
- **Hardcoded default** is the fallback when nothing is configured anywhere.

### 6.2 Resolution Service

```ruby
# lib/inboxed/services/resolve_setting.rb
module Inboxed
  module Services
    class ResolveSetting
      REGISTRY = {
        "registration_mode"      => { type: :string,  default: "closed",  env: "REGISTRATION_MODE",                category: "general" },
        "trial_duration_days"    => { type: :integer, default: 7,         env: "TRIAL_DURATION_DAYS",              category: "general" },
        "email_ttl_hours"        => { type: :integer, default: 168,       env: "EMAIL_TTL_HOURS",                  category: "email" },
        "max_emails_per_project" => { type: :integer, default: 10_000,    env: "INBOXED_MAX_EMAILS_PER_PROJECT",   category: "limits" },
        "max_message_size_mb"    => { type: :integer, default: 3,         env: "INBOXED_MAX_MESSAGE_SIZE_MB",      category: "limits" },
        "max_inbox_count"        => { type: :integer, default: 100,       env: "INBOXED_MAX_INBOX_COUNT",          category: "limits" },
        "feature_hooks"          => { type: :boolean, default: true,      env: "INBOXED_FEATURE_HOOKS",            category: "features" },
        "feature_forms"          => { type: :boolean, default: true,      env: "INBOXED_FEATURE_FORMS",            category: "features" },
        "feature_heartbeats"     => { type: :boolean, default: true,      env: "INBOXED_FEATURE_HEARTBEATS",       category: "features" },
        "feature_inbound_email"  => { type: :boolean, default: false,     env: "INBOXED_FEATURE_INBOUND_EMAIL",    category: "features" },
        "rate_limit_api"         => { type: :integer, default: 300,       env: "RATE_LIMIT_API",                   category: "security" },
        "rate_limit_auth"        => { type: :integer, default: 5,         env: "RATE_LIMIT_AUTH",                   category: "security" }
      }.freeze

      PROJECT_OVERRIDABLE = %w[
        feature_hooks feature_forms feature_heartbeats feature_inbound_email
        email_ttl_hours max_emails_per_project max_inbox_count
      ].freeze

      def self.call(key, project_id: nil)
        entry = REGISTRY.fetch(key)

        # Layer 1: ENV var override (highest priority)
        env_value = ENV[entry[:env]]
        if env_value.present?
          return { value: cast(env_value, entry[:type]), source: :env }
        end

        # Layer 2: Project setting (if project context and setting is overridable)
        if project_id && PROJECT_OVERRIDABLE.include?(key)
          project_value = SiteConfigCache.project_setting(project_id, key)
          if project_value
            return { value: cast(project_value, entry[:type]), source: :project }
          end
        end

        # Layer 3: Site setting (DB)
        site_value = SiteConfigCache.site_setting(key)
        if site_value
          return { value: cast(site_value, entry[:type]), source: :db }
        end

        # Layer 4: Hardcoded default
        { value: entry[:default], source: :default }
      end

      def self.cast(value, type)
        case type
        when :string  then value.to_s
        when :integer then value.to_i
        when :boolean then ActiveModel::Type::Boolean.new.cast(value)
        when :json    then JSON.parse(value)
        end
      end
    end
  end
end
```

### 6.3 Convenience Accessor

```ruby
# lib/inboxed/site_config.rb
module Inboxed
  module SiteConfig
    def self.get(key, project_id: nil)
      result = Services::ResolveSetting.call(key, project_id: project_id)
      result[:value]
    end

    def self.get_with_source(key, project_id: nil)
      Services::ResolveSetting.call(key, project_id: project_id)
    end

    # Convenience methods for common checks
    def self.feature_enabled?(feature, project_id: nil)
      get("feature_#{feature}", project_id: project_id)
    end

    def self.registration_mode
      get("registration_mode")
    end

    def self.max_emails_per_project(project_id: nil)
      get("max_emails_per_project", project_id: project_id)
    end
  end
end
```

Usage throughout the codebase:

```ruby
# Before (env var):
if ENV.fetch("INBOXED_FEATURE_INBOUND_EMAIL", "false") == "true"

# After (site config):
if Inboxed::SiteConfig.feature_enabled?(:inbound_email)

# With project context:
if Inboxed::SiteConfig.feature_enabled?(:inbound_email, project_id: project.id)
```

---

## 7. Cache Layer

### 7.1 Design

Class-level in-memory cache with a 30-second TTL. On first access (or after TTL expiry), the cache loads all settings from the database in a single query. Subsequent reads within the TTL window are pure memory lookups — no DB hit.

### 7.2 Implementation

```ruby
# lib/inboxed/site_config_cache.rb
module Inboxed
  class SiteConfigCache
    CACHE_TTL = 30.seconds

    class << self
      def site_setting(key)
        refresh_site_cache_if_stale
        @site_cache&.dig(key)
      end

      def project_setting(project_id, key)
        refresh_project_cache_if_stale(project_id)
        @project_cache&.dig(project_id, key)
      end

      def all_site_settings
        refresh_site_cache_if_stale
        @site_cache || {}
      end

      def all_project_settings(project_id)
        refresh_project_cache_if_stale(project_id)
        @project_cache&.dig(project_id) || {}
      end

      def invalidate!
        @site_cache = nil
        @site_cache_loaded_at = nil
        @project_cache = nil
        @project_cache_loaded_at = nil
      end

      private

      def refresh_site_cache_if_stale
        if @site_cache_loaded_at.nil? || @site_cache_loaded_at < CACHE_TTL.ago
          @site_cache = SettingRecord.pluck(:key, :value).to_h
          @site_cache_loaded_at = Time.current
        end
      end

      def refresh_project_cache_if_stale(project_id)
        @project_cache ||= {}
        @project_cache_loaded_at ||= {}

        loaded_at = @project_cache_loaded_at[project_id]
        if loaded_at.nil? || loaded_at < CACHE_TTL.ago
          @project_cache[project_id] = ProjectSettingRecord
            .where(project_id: project_id)
            .pluck(:key, :value)
            .to_h
          @project_cache_loaded_at[project_id] = Time.current
        end
      end
    end
  end
end
```

### 7.3 Cache Behavior

| Scenario | Behavior |
|----------|----------|
| First request after boot | Cache miss → single DB query loads all settings → cached for 30s |
| Subsequent requests within 30s | Cache hit → pure memory lookup, zero DB queries |
| Request after 30s | Cache expired → reload from DB → cached for another 30s |
| Admin updates a setting via API | DB updated immediately, cache expires naturally within 30s |
| Tests | Call `SiteConfigCache.invalidate!` in test setup to reset state |

### 7.4 Why Not Active Cache Invalidation?

Active invalidation (e.g., after every `PATCH /admin/settings`) adds complexity for minimal gain. Settings changes are rare (minutes to hours between changes), and a 30-second staleness window is acceptable for a dev tool. The simplicity of TTL-based expiry outweighs the marginal benefit of instant propagation.

---

## 8. Admin API Endpoints

All settings endpoints require admin token authentication (`Authorization: Bearer <INBOXED_ADMIN_TOKEN>`). Regular API key auth cannot access settings.

### 8.1 `GET /admin/settings`

Returns all settings grouped by category, with the current effective value and its source.

```json
// Response 200
{
  "data": {
    "general": [
      {
        "key": "registration_mode",
        "value": "closed",
        "value_type": "string",
        "source": "default",
        "description": "Registration policy: open, invite_only, closed",
        "options": ["open", "invite_only", "closed"]
      },
      {
        "key": "trial_duration_days",
        "value": 7,
        "value_type": "integer",
        "source": "db",
        "description": "Trial duration in days for new organizations"
      }
    ],
    "features": [
      {
        "key": "feature_hooks",
        "value": true,
        "value_type": "boolean",
        "source": "db",
        "description": "Enable webhook delivery",
        "project_overridable": true
      },
      {
        "key": "feature_inbound_email",
        "value": false,
        "value_type": "boolean",
        "source": "env",
        "description": "Enable inbound email content",
        "project_overridable": true,
        "env_override": "INBOXED_FEATURE_INBOUND_EMAIL"
      }
    ],
    "limits": [
      {
        "key": "max_emails_per_project",
        "value": 10000,
        "value_type": "integer",
        "source": "default",
        "description": "Maximum emails per project",
        "project_overridable": true
      }
    ],
    "email": [
      {
        "key": "email_ttl_hours",
        "value": 168,
        "value_type": "integer",
        "source": "db",
        "description": "Default email retention in hours",
        "project_overridable": true
      }
    ],
    "security": [
      {
        "key": "rate_limit_api",
        "value": 300,
        "value_type": "integer",
        "source": "default",
        "description": "API rate limit per period"
      },
      {
        "key": "rate_limit_auth",
        "value": 5,
        "value_type": "integer",
        "source": "env",
        "description": "Auth rate limit per period",
        "env_override": "RATE_LIMIT_AUTH"
      }
    ]
  }
}
```

**Notes:**
- `source` is one of: `env`, `db`, `default`
- When `source` is `env`, the `env_override` field names the active env var
- `project_overridable` indicates whether per-project overrides are allowed
- `options` field is present for enum-type settings (like `registration_mode`)
- Values are returned in their typed form (integers as numbers, booleans as true/false)

### 8.2 `PATCH /admin/settings`

Bulk update settings. Accepts a flat key-value map. Only keys present in the request body are updated.

```json
// Request
{
  "settings": {
    "registration_mode": "open",
    "trial_duration_days": 14,
    "feature_inbound_email": true
  }
}

// Response 200
{
  "data": {
    "updated": ["registration_mode", "trial_duration_days", "feature_inbound_email"],
    "skipped": [],
    "errors": []
  }
}
```

**Validation:**
- Unknown keys are rejected with an error
- Type mismatches are rejected (e.g., string value for an integer setting)
- Settings overridden by env vars are accepted but a warning is included:

```json
// Response 200 (with env var warning)
{
  "data": {
    "updated": ["registration_mode", "trial_duration_days"],
    "skipped": [
      {
        "key": "feature_inbound_email",
        "reason": "Overridden by environment variable INBOXED_FEATURE_INBOUND_EMAIL"
      }
    ],
    "errors": []
  }
}
```

The DB value is still updated (for when the env var is removed), but the response warns that the env var takes precedence.

### 8.3 `GET /admin/projects/:id/settings`

Returns per-project setting overrides and the effective values.

```json
// Response 200
{
  "data": {
    "project_id": "p1a2b3c4-...",
    "settings": [
      {
        "key": "feature_inbound_email",
        "value": true,
        "effective_value": true,
        "source": "project",
        "global_value": false,
        "description": "Enable inbound email content"
      },
      {
        "key": "feature_hooks",
        "value": null,
        "effective_value": true,
        "source": "db",
        "global_value": true,
        "description": "Enable webhook delivery"
      }
    ]
  }
}
```

**Notes:**
- `value` is the project-level override (null if not set)
- `effective_value` is the resolved value after the full resolution chain
- `source` shows where the effective value comes from
- `global_value` shows the site-level default for comparison
- Only project-overridable settings are listed

### 8.4 `PATCH /admin/projects/:id/settings`

Update per-project setting overrides.

```json
// Request
{
  "settings": {
    "feature_inbound_email": true,
    "max_emails_per_project": 50000
  }
}

// Response 200
{
  "data": {
    "updated": ["feature_inbound_email", "max_emails_per_project"],
    "errors": []
  }
}
```

**Validation:**
- Only project-overridable keys are accepted
- Non-overridable keys are rejected with an error
- Setting a value to `null` removes the project override (falls back to global)

---

## 9. Dashboard Settings Page

### 9.1 Route

```
/admin/settings
```

Accessible from the sidebar (admin section) or via the command palette.

### 9.2 Layout

Two-column layout with settings grouped by category:

```
┌─────────────────────────────────────────────────────────────────┐
│  ⚙ Site Settings                                         [Save] │
│─────────────────────────────────────────────────────────────────│
│                                                                 │
│  GENERAL                                                        │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  Registration Mode          [  closed  ▾]                       │
│  How new users join this instance                               │
│                                                                 │
│  Trial Duration (days)      [  7  ]                             │
│  Trial duration for new organizations                           │
│                                                                 │
│  FEATURES                                                       │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  Webhooks                   [■ ON ]                              │
│  Enable webhook delivery for email events                       │
│                                                                 │
│  Forms                      [■ ON ]                              │
│  Enable form capture endpoints                                  │
│                                                                 │
│  Heartbeats                 [■ ON ]                              │
│  Enable heartbeat monitoring                                    │
│                                                                 │
│  Inbound Email              [□ OFF] ⚠ Overridden by env var     │
│  Enable inbound email content                                   │
│                                                                 │
│  LIMITS                                                         │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  Max Emails per Project     [  10000  ]                         │
│  Maximum stored emails per project                              │
│                                                                 │
│  Max Message Size (MB)      [  3  ]                             │
│  Maximum email message size                                     │
│                                                                 │
│  Max Inboxes per Project    [  100  ]                           │
│  Maximum inboxes per project                                    │
│                                                                 │
│  EMAIL                                                          │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  Email Retention (hours)    [  168  ]                           │
│  How long emails are stored (168 = 7 days)                      │
│                                                                 │
│  SECURITY                                                       │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  API Rate Limit             [  300  ]                           │
│  Requests per rate limit period                                 │
│                                                                 │
│  Auth Rate Limit            [  5  ]                             │
│  Authentication attempts per period                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 9.3 Input Types

| Setting Type | UI Control |
|-------------|------------|
| Boolean (feature flags) | Toggle switch (ON/OFF) |
| Integer (limits, durations) | Number input with increment/decrement |
| String enum (registration_mode) | Dropdown select |

### 9.4 Env Var Override Indicator

When a setting is overridden by an environment variable:

- The input is **disabled** (grayed out, non-interactive)
- A warning badge appears: `Overridden by environment variable`
- Tooltip on hover: `This setting is controlled by the INBOXED_FEATURE_INBOUND_EMAIL environment variable. Remove the env var to manage it from the dashboard.`
- The displayed value reflects the env var value, not the DB value

### 9.5 Source Indicator

Each setting shows subtle hint text indicating where the current value comes from:

- `Set via environment variable` — env var override active
- `Custom value` — DB value differs from default
- `Default` — using hardcoded default (no DB row)

### 9.6 Save Behavior

- The "Save" button sends a `PATCH /admin/settings` with all changed values
- A toast notification confirms: "Settings saved" or shows validation errors
- Changes take effect within 30 seconds (cache TTL)
- The page does not reload — values update in place

### 9.7 Project Settings Override UI

On each project's settings page (`/projects/:id/settings`), a "Feature Flags" section shows toggles for project-overridable settings:

```
┌─────────────────────────────────────────────────────────────────┐
│  Feature Overrides (this project only)                          │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  Inbound Email              [■ ON ]   (global: OFF)             │
│  Webhooks                   [  Use global default  ]            │
│  Forms                      [  Use global default  ]            │
│  Heartbeats                 [  Use global default  ]            │
│                                                                 │
│  Overrides apply only to this project.                          │
│  Global defaults are managed in Site Settings.                  │
└─────────────────────────────────────────────────────────────────┘
```

Each toggle has three states:
- **Use global default** — no project override, inherits site setting
- **ON** — project override enabled
- **OFF** — project override disabled

---

## 10. Seed Data

### 10.1 Seed File

```ruby
# db/seeds/settings.rb
SEED_SETTINGS = [
  { key: "registration_mode",      value: "closed", value_type: "string",  category: "general",  description: "Registration policy: open, invite_only, closed" },
  { key: "trial_duration_days",    value: "7",      value_type: "integer", category: "general",  description: "Trial duration in days for new organizations" },
  { key: "email_ttl_hours",        value: "168",    value_type: "integer", category: "email",    description: "Default email retention in hours" },
  { key: "max_emails_per_project", value: "10000",  value_type: "integer", category: "limits",   description: "Maximum stored emails per project" },
  { key: "max_message_size_mb",    value: "3",      value_type: "integer", category: "limits",   description: "Maximum email message size in megabytes" },
  { key: "max_inbox_count",        value: "100",    value_type: "integer", category: "limits",   description: "Maximum inboxes per project" },
  { key: "feature_hooks",          value: "true",   value_type: "boolean", category: "features", description: "Enable webhook delivery for email events" },
  { key: "feature_forms",          value: "true",   value_type: "boolean", category: "features", description: "Enable form capture endpoints" },
  { key: "feature_heartbeats",     value: "true",   value_type: "boolean", category: "features", description: "Enable heartbeat monitoring" },
  { key: "feature_inbound_email",  value: "false",  value_type: "boolean", category: "features", description: "Enable inbound email content" },
  { key: "rate_limit_api",         value: "300",    value_type: "integer", category: "security", description: "API requests allowed per rate limit period" },
  { key: "rate_limit_auth",        value: "5",      value_type: "integer", category: "security", description: "Authentication attempts allowed per rate limit period" }
].freeze

SEED_SETTINGS.each do |attrs|
  SettingRecord.find_or_create_by!(key: attrs[:key]) do |s|
    s.value = attrs[:value]
    s.value_type = attrs[:value_type]
    s.category = attrs[:category]
    s.description = attrs[:description]
  end
end
```

### 10.2 When Seeds Run

- `bin/setup` calls `rails db:seed` after `db:migrate`
- `db:seed` is idempotent — `find_or_create_by!` ensures existing settings are not overwritten
- New settings added in future versions are automatically seeded on next `db:seed` run
- Operators can safely re-run `bin/setup` without losing their customized settings

---

## 11. Technical Decisions

### 11.1 Decision: PostgreSQL Over Redis for Settings Storage

- **Options considered:** (A) Redis, (B) PostgreSQL, (C) YAML file
- **Chosen:** B — PostgreSQL `settings` table
- **Why:** Already have PG, zero new dependencies. Settings are queryable, auditable, transactional. The in-memory cache eliminates the read performance advantage of Redis.
- **Trade-offs:** Slightly more complex than a YAML file. Acceptable because it enables the admin UI and per-project overrides.

### 11.2 Decision: TTL-Based Cache Over Active Invalidation

- **Options considered:** (A) No cache (DB on every read), (B) TTL-based class cache, (C) Active invalidation via pub/sub
- **Chosen:** B — TTL-based class-level cache (30 seconds)
- **Why:** Settings change rarely (minutes to hours between changes). A 30-second staleness window is acceptable for a dev tool. Active invalidation adds complexity (pub/sub, cache coherence) for marginal benefit.
- **Trade-offs:** Up to 30s delay for settings changes to take effect. The admin UI warns about this.

### 11.3 Decision: ENV Var Precedence

- **Options considered:** (A) DB overrides env, (B) Env overrides DB
- **Chosen:** B — ENV vars always win
- **Why (Security Engineer):** "The operator should always be able to force a setting via environment, regardless of what's in the DB. If someone gains admin dashboard access and enables a dangerous feature, the operator can lock it down with an env var without touching the DB."
- **Trade-offs:** Two sources of truth can be confusing. Mitigated by the `source` field in API responses and override indicators in the dashboard.

### 11.4 Decision: Flat API Over Per-Setting CRUD

- **Options considered:** (A) RESTful per-setting (`GET/PATCH /admin/settings/:key`), (B) Flat bulk API
- **Chosen:** B — Flat bulk API
- **Why (API Design Architect):** "There are ~12 settings. Making each one a separate REST resource means 12 endpoints, 12 serializers, 12 request specs. A flat `GET /admin/settings` + `PATCH /admin/settings` is simpler, faster to build, and matches how the dashboard consumes it — load all, save changed ones."
- **Trade-offs:** No individual setting URLs. Acceptable because settings are always viewed and edited as a group.

### 11.5 Decision: Settings Values Stored as Strings

- **Options considered:** (A) Type-specific columns (string_value, int_value, bool_value), (B) JSONB value column, (C) String value with type metadata
- **Chosen:** C — String value with `value_type` column for casting
- **Why:** Simplest schema. One column, one type indicator, casting in application code. Avoids nullable column sprawl (option A) and JSON parsing overhead for simple values (option B).
- **Trade-offs:** Application must handle type casting. Mitigated by the centralized `cast` method in `ResolveSetting`.

---

## 12. Implementation Plan

### Step 1: Database Migrations

1. Create `settings` table migration (section 4.5)
2. Create `project_settings` table migration (section 4.5)
3. Run migrations
4. Verify tables and indexes exist

### Step 2: Domain Layer

1. Create `Inboxed::Entities::Setting` (Dry::Struct)
2. Create `Inboxed::Entities::ProjectSetting` (Dry::Struct)
3. Create `SettingRecord` ActiveRecord model
4. Create `ProjectSettingRecord` ActiveRecord model

### Step 3: Settings Registry and Resolution

1. Create `Inboxed::Services::ResolveSetting` with full registry (section 6.2)
2. Create `Inboxed::SiteConfig` convenience module (section 6.3)
3. Create `Inboxed::SiteConfigCache` with TTL logic (section 7.2)
4. Write unit tests for resolution order: env → project → site → default
5. Write unit tests for type casting

### Step 4: Seed Data

1. Create `db/seeds/settings.rb` with all default settings (section 10.1)
2. Include in `db/seeds.rb`
3. Run `db:seed` and verify all 12 settings exist
4. Run `db:seed` again — verify idempotency (no duplicates)

### Step 5: Repositories

1. Create `SettingRepository` — `all`, `find_by_key`, `update`, `bulk_update`
2. Create `ProjectSettingRepository` — `for_project`, `upsert`, `delete`

### Step 6: Admin API — Site Settings

1. Create `Admin::SettingsController` with `index` and `update` actions
2. Add routes: `GET /admin/settings`, `PATCH /admin/settings`
3. Implement grouped response with source indicators (section 8.1)
4. Implement bulk update with validation and env var warnings (section 8.2)
5. Write request specs

### Step 7: Admin API — Project Settings

1. Create `Admin::Projects::SettingsController` with `show` and `update` actions
2. Add routes: `GET /admin/projects/:id/settings`, `PATCH /admin/projects/:id/settings`
3. Implement effective value display with global comparison (section 8.3)
4. Implement override create/update/delete (section 8.4)
5. Write request specs

### Step 8: Migrate Existing Code

1. Find all `ENV.fetch("INBOXED_FEATURE_*")` calls and replace with `SiteConfig.feature_enabled?`
2. Find all `ENV.fetch("REGISTRATION_MODE")` calls and replace with `SiteConfig.registration_mode`
3. Replace other config env var reads with `SiteConfig.get` calls
4. Verify existing tests pass (env vars still work via resolution order)

### Step 9: Dashboard Settings Page

1. Create settings API client in dashboard (`settingsService.ts`)
2. Create `SettingsPage.svelte` with grouped sections
3. Implement toggle switches, number inputs, dropdown selects
4. Implement env var override indicators (disabled inputs + warning badges)
5. Implement save with toast notification
6. Add route `/admin/settings` and sidebar link
7. Add command palette entry: "Go to Settings"

### Step 10: Dashboard Project Settings Override

1. Add "Feature Overrides" section to project settings page
2. Implement tri-state toggles (use global / ON / OFF)
3. Wire to `PATCH /admin/projects/:id/settings`
4. Show global default value for comparison

### Step 11: Tests and Verification

1. Unit tests: `ResolveSetting` with all resolution layers
2. Unit tests: `SiteConfigCache` TTL behavior
3. Request specs: all 4 admin API endpoints
4. Integration test: change setting via API → verify cache picks it up within 30s
5. Integration test: env var overrides DB setting
6. Verify `bin/setup` seeds defaults correctly
7. Run `standardrb` and `rspec` — zero errors

---

## 13. File Structure (New Files)

```
apps/api/
├── app/
│   ├── domain/entities/
│   │   ├── setting.rb
│   │   └── project_setting.rb
│   ├── models/
│   │   ├── setting_record.rb
│   │   └── project_setting_record.rb
│   ├── controllers/admin/
│   │   ├── settings_controller.rb
│   │   └── projects/
│   │       └── settings_controller.rb
│   └── serializers/
│       ├── setting_serializer.rb
│       └── project_setting_serializer.rb
├── lib/inboxed/
│   ├── site_config.rb
│   ├── site_config_cache.rb
│   ├── services/
│   │   └── resolve_setting.rb
│   └── repositories/
│       ├── setting_repository.rb
│       └── project_setting_repository.rb
├── db/
│   ├── migrate/
│   │   ├── xxx_create_settings.rb
│   │   └── xxx_create_project_settings.rb
│   └── seeds/
│       └── settings.rb
└── spec/
    ├── lib/inboxed/
    │   ├── site_config_spec.rb
    │   ├── site_config_cache_spec.rb
    │   └── services/resolve_setting_spec.rb
    ├── models/
    │   ├── setting_record_spec.rb
    │   └── project_setting_record_spec.rb
    └── requests/admin/
        ├── settings_spec.rb
        └── projects/settings_spec.rb

apps/dashboard/
└── src/
    ├── features/settings/
    │   ├── SettingsPage.svelte
    │   ├── SettingsSection.svelte
    │   ├── SettingToggle.svelte
    │   ├── SettingNumber.svelte
    │   ├── SettingSelect.svelte
    │   ├── EnvOverrideBadge.svelte
    │   ├── settings.service.ts
    │   ├── settings.store.svelte.ts
    │   └── settings.types.ts
    └── routes/admin/
        └── settings/+page.svelte
```

---

## 14. Exit Criteria

### Data Model

- [ ] **EC-001:** `settings` table exists with `key`, `value`, `value_type`, `category`, `description` columns
- [ ] **EC-002:** `project_settings` table exists with `project_id`, `key`, `value`, `value_type` columns
- [ ] **EC-003:** `settings.key` has a unique index
- [ ] **EC-004:** `project_settings.(project_id, key)` has a unique composite index
- [ ] **EC-005:** All 12 default settings are seeded via `db:seed`
- [ ] **EC-006:** `db:seed` is idempotent — running twice does not duplicate settings

### Resolution Logic

- [ ] **EC-007:** `SiteConfig.get("key")` returns the correct value from the highest-priority source
- [ ] **EC-008:** ENV var overrides DB setting — `ENV["INBOXED_FEATURE_HOOKS"]="false"` wins over `settings.feature_hooks = true`
- [ ] **EC-009:** Project setting overrides site setting — project override `true` wins over global `false`
- [ ] **EC-010:** ENV var overrides project setting — env var always wins regardless of project override
- [ ] **EC-011:** Missing DB row falls back to hardcoded default
- [ ] **EC-012:** Type casting works correctly: string, integer, boolean, json

### Cache

- [ ] **EC-013:** First `SiteConfig.get` call triggers a single DB query (loads all settings)
- [ ] **EC-014:** Subsequent calls within 30s return cached values (zero DB queries)
- [ ] **EC-015:** After 30s, cache reloads from DB on next access
- [ ] **EC-016:** `SiteConfigCache.invalidate!` resets all caches (for tests)

### Admin API

- [ ] **EC-017:** `GET /admin/settings` returns all settings grouped by category with source indicators
- [ ] **EC-018:** `PATCH /admin/settings` updates multiple settings in one request
- [ ] **EC-019:** `PATCH /admin/settings` rejects unknown keys with error
- [ ] **EC-020:** `PATCH /admin/settings` warns when updating a setting overridden by env var
- [ ] **EC-021:** `GET /admin/projects/:id/settings` returns project overrides with effective values
- [ ] **EC-022:** `PATCH /admin/projects/:id/settings` creates/updates project overrides
- [ ] **EC-023:** `PATCH /admin/projects/:id/settings` with `null` value removes the override
- [ ] **EC-024:** `PATCH /admin/projects/:id/settings` rejects non-overridable keys
- [ ] **EC-025:** All settings endpoints require admin token auth (reject API key auth)

### Dashboard

- [ ] **EC-026:** Settings page (`/admin/settings`) renders all settings grouped by category
- [ ] **EC-027:** Boolean settings render as toggle switches
- [ ] **EC-028:** Integer settings render as number inputs
- [ ] **EC-029:** Enum settings render as dropdown selects
- [ ] **EC-030:** Settings overridden by env vars show disabled input + warning badge
- [ ] **EC-031:** Save button sends `PATCH /admin/settings` and shows success/error toast
- [ ] **EC-032:** Project settings page shows feature override toggles with tri-state (global/on/off)

### Integration

- [ ] **EC-033:** End-to-end: admin changes `registration_mode` to `open` via dashboard → new users can register within 30s
- [ ] **EC-034:** End-to-end: admin enables `feature_inbound_email` for one project → that project receives full inbound email, others don't
- [ ] **EC-035:** Existing env var deployments work unchanged — all env vars are still read and respected
- [ ] **EC-036:** `standardrb` and `rspec` pass with zero errors

---

## 15. Open Questions

1. **Cache TTL tuning:** Is 30 seconds the right TTL? Too short = unnecessary DB queries, too long = stale settings. 30s is a reasonable starting point. Could be made configurable via env var (`SITE_CONFIG_CACHE_TTL_SECONDS`) if operators need faster propagation.

2. **Settings history/audit log:** Should we track who changed what and when? The `updated_at` column provides basic tracking, but a full audit log (old value → new value, changed by user) would require an additional table. Recommendation: defer to a future spec. The `settings` table's `updated_at` is sufficient for now.

3. **Settings export/import:** Should there be an API to export all settings as JSON and import them on another instance? Useful for replicating configuration across staging/production. Recommendation: defer. The seed file handles defaults, and manual API calls handle customization. Export/import is a nice-to-have for multi-instance operators.

4. **Rate limit cache interaction:** Rate limits are currently applied by Rack::Attack at the middleware level, which reads from env vars at boot. Changing rate limits via site config requires Rack::Attack to re-read the values. This may need a custom Rack::Attack throttle that delegates to `SiteConfig` instead of using hardcoded values. Investigate during implementation.

5. **Multi-process cache coherence:** In a multi-process deployment (Puma workers), each process has its own in-memory cache. A setting change in the DB will be picked up independently by each worker within 30s. This is acceptable — there's no guarantee of exact-same-second propagation across workers, but 30s convergence is fine for a dev tool.
