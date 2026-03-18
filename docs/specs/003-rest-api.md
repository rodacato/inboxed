# 003 — REST API

> Programmatic access to projects, inboxes, emails, and attachments via a versioned JSON API with authentication, pagination, rate limiting, and OpenAPI documentation.

**Phase:** Phase 2 (REST API)
**Status:** implemented
**Release:** —
**Depends on:** [001-architecture](001-architecture.md), [002-smtp-persistence](002-smtp-persistence.md)

---

## Objective

Expose all Inboxed functionality through a REST API that developers, CI scripts, the Svelte dashboard, and the MCP server can consume. The API is the single source of truth — every feature in the system is accessible through it.

By the end of this spec, a developer can:
- Create and manage projects and API keys
- List inboxes and browse emails with pagination
- Search emails by full-text query
- Wait for an incoming email (long-poll)
- Download attachments and raw MIME source
- Do all of the above from `curl` with a single `Authorization` header

---

## Context

### Current State

- Spec 002 delivers SMTP reception, MIME parsing, and email persistence through the event store
- Domain layer complete: `ProjectAggregate`, `InboxAggregate`, value objects, events
- Two auth strategies established: API key (Bearer token) for project-scoped endpoints, admin token for system-wide endpoints
- Two status endpoints (`/api/v1/status`, `/admin/status`) verify the auth flows work
- Database schema with full-text search index on `emails(subject, body_text)` via `to_tsvector`
- No resource endpoints, no serializers, no read models

### What This Spec Delivers

1. **Admin endpoints** — project and API key CRUD
2. **API v1 endpoints** — inboxes, emails, attachments, search, wait
3. **Read models** — query-optimized models for list/detail views (per architecture spec)
4. **Serializers** — consistent JSON response formatting (per [ADR-008](../adrs/008-api-response-format.md))
5. **Cursor pagination** — efficient, stable pagination (per [ADR-009](../adrs/009-cursor-pagination.md))
6. **Rate limiting** — per-key and per-IP throttling (per [ADR-010](../adrs/010-rate-limiting.md))
7. **API key validation** — complete the auth flow (currently a TODO in `Api::V1::BaseController`)
8. **OpenAPI spec & Redocly** — machine-readable API documentation
9. **Request specs** — full coverage of all endpoints

### Constraints

- Controllers are thin — parse params, call service or read model, serialize response (spec 001 rule C1)
- Queries use read models, not repositories (spec 001 rule R1)
- Commands go through application services → aggregates → event store (spec 001 rules A1, A2)
- Error responses follow RFC 7807 Problem Details (ADR-008)
- All timestamps in ISO 8601 UTC
- No breaking changes to existing `/api/v1/status` or `/admin/status` endpoints

---

## API Design

### Authentication

Two parallel auth strategies (unchanged from spec 000):

| Strategy | Header | Scope | Used by |
|----------|--------|-------|---------|
| **API key** | `Authorization: Bearer <api_key>` | Project-scoped operations | Dashboard, MCP server, test helpers, CI |
| **Admin token** | `Authorization: Bearer <admin_token>` | System-wide operations | Dashboard (admin views), CLI |

API key validation flow (completing the TODO from spec 000):

```ruby
# Api::V1::BaseController
def authenticate_api_key!
  token = extract_bearer_token
  return render_unauthorized("API key required") unless token

  prefix = token[0..7]
  candidates = ApiKeyRecord.where(token_prefix: prefix).includes(:project)
  api_key = candidates.find { |k| BCrypt::Password.new(k.token_digest) == token }

  unless api_key
    request.env["inboxed.auth_failed"] = true  # for Rack::Attack
    return render_unauthorized("Invalid API key")
  end

  @current_api_key = api_key
  @current_project = api_key.project
  api_key.update_column(:last_used_at, Time.current)
end
```

The `@current_project` scopes all queries in API v1 controllers. An API key can only access resources within its project.

### Endpoint Map

#### Admin Endpoints (`/admin/`)

Auth: `INBOXED_ADMIN_TOKEN`

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| GET | `/admin/projects` | index | List all projects |
| POST | `/admin/projects` | create | Create a project |
| GET | `/admin/projects/:id` | show | Get project details + stats |
| PATCH | `/admin/projects/:id` | update | Update project settings |
| DELETE | `/admin/projects/:id` | destroy | Delete project (cascades) |
| POST | `/admin/projects/:id/api_keys` | create | Issue a new API key |
| GET | `/admin/projects/:id/api_keys` | index | List API keys for project |
| PATCH | `/admin/api_keys/:id` | update | Update API key label |
| DELETE | `/admin/api_keys/:id` | destroy | Revoke API key |

#### API v1 Endpoints (`/api/v1/`)

Auth: Project API key (Bearer token)

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| GET | `/api/v1/inboxes` | index | List inboxes in current project |
| GET | `/api/v1/inboxes/:id` | show | Get inbox details |
| DELETE | `/api/v1/inboxes/:id` | destroy | Delete inbox + all emails |
| DELETE | `/api/v1/inboxes/:id/emails` | purge | Delete all emails in inbox |
| GET | `/api/v1/inboxes/:id/emails` | index | List emails in inbox (paginated) |
| GET | `/api/v1/emails/:id` | show | Get email detail (metadata + body) |
| GET | `/api/v1/emails/:id/raw` | raw | Get raw MIME source (`text/plain`) |
| DELETE | `/api/v1/emails/:id` | destroy | Delete single email |
| GET | `/api/v1/emails/:id/attachments` | index | List email attachments (metadata) |
| GET | `/api/v1/attachments/:id/download` | download | Download attachment binary |
| GET | `/api/v1/search` | search | Full-text search across project emails |
| POST | `/api/v1/emails/wait` | wait | Long-poll for new email (up to 30s) |

### Endpoint Details

#### `GET /api/v1/inboxes`

List all inboxes in the current project, sorted by most recent email activity.

```
GET /api/v1/inboxes?limit=20&after=<cursor>
```

Response:

```json
{
  "inboxes": [
    {
      "id": "...",
      "address": "user@mail.inboxed.dev",
      "email_count": 12,
      "last_email_at": "2026-03-15T10:30:00Z",
      "created_at": "2026-03-15T09:00:00Z"
    }
  ],
  "pagination": {
    "has_more": false,
    "next_cursor": null,
    "total_count": 5
  }
}
```

#### `GET /api/v1/inboxes/:id/emails`

List emails in an inbox, sorted by `received_at DESC`.

```
GET /api/v1/inboxes/:id/emails?limit=20&after=<cursor>
```

Response:

```json
{
  "emails": [
    {
      "id": "...",
      "from": "app@mycompany.com",
      "to": ["user@mail.inboxed.dev"],
      "subject": "Verify your email",
      "preview": "Click the link below to verify...",
      "has_attachments": true,
      "attachment_count": 1,
      "source_type": "relay",
      "received_at": "2026-03-15T10:30:00Z"
    }
  ],
  "pagination": {
    "has_more": true,
    "next_cursor": "eyJyZWNlaXZlZF9hdCI6Ii4uLiIsImlkIjoiLi4uIn0=",
    "total_count": 342
  }
}
```

The email list uses a **lightweight projection** — no `body_html`, `body_text`, or `raw_source`. The `preview` field is a truncated plaintext excerpt (200 chars max).

#### `GET /api/v1/emails/:id`

Full email detail.

```json
{
  "email": {
    "id": "...",
    "inbox_id": "...",
    "from": "app@mycompany.com",
    "to": ["user@mail.inboxed.dev"],
    "cc": [],
    "subject": "Verify your email",
    "body_html": "<html>...",
    "body_text": "Click the link below...",
    "raw_headers": { "X-Mailer": "MyApp 1.0", "Message-ID": "<abc@myapp>" },
    "source_type": "relay",
    "received_at": "2026-03-15T10:30:00Z",
    "expires_at": "2026-03-22T10:30:00Z",
    "attachments": [
      {
        "id": "...",
        "filename": "receipt.pdf",
        "content_type": "application/pdf",
        "size_bytes": 45231,
        "inline": false,
        "download_url": "/api/v1/attachments/.../download"
      }
    ]
  }
}
```

#### `GET /api/v1/emails/:id/raw`

Returns the raw MIME source as `text/plain`. No JSON envelope.

```
Content-Type: text/plain; charset=utf-8
Content-Disposition: inline; filename="email.eml"

From: app@mycompany.com
To: user@mail.inboxed.dev
Subject: Verify your email
MIME-Version: 1.0
...
```

#### `GET /api/v1/attachments/:id/download`

Returns the binary attachment content.

```
Content-Type: application/pdf
Content-Disposition: attachment; filename="receipt.pdf"
Content-Length: 45231

<binary content>
```

#### `GET /api/v1/search`

Full-text search across all emails in the current project.

```
GET /api/v1/search?q=verify+email&limit=20&after=<cursor>
```

Uses PostgreSQL `to_tsvector`/`to_tsquery` against the existing GIN index on `subject + body_text`.

```json
{
  "emails": [
    {
      "id": "...",
      "inbox_id": "...",
      "inbox_address": "user@mail.inboxed.dev",
      "from": "app@mycompany.com",
      "subject": "Verify your email",
      "preview": "Click the link below to verify...",
      "received_at": "2026-03-15T10:30:00Z",
      "relevance": 0.85
    }
  ],
  "pagination": {
    "has_more": false,
    "next_cursor": null,
    "total_count": 3
  }
}
```

Search results are ranked by `ts_rank` relevance and include `inbox_address` since results span multiple inboxes.

#### `POST /api/v1/emails/wait`

Long-poll endpoint. Blocks until a matching email arrives or timeout expires. This is the key endpoint for test automation — "send email, wait for it to appear."

```json
// Request body
{
  "inbox_address": "user@mail.inboxed.dev",
  "subject_pattern": "Verify.*",
  "timeout_seconds": 30
}
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `inbox_address` | string | yes | — | Email address to watch |
| `subject_pattern` | string | no | — | Regex pattern to match subject |
| `timeout_seconds` | integer | no | 30 | Max wait time (1-30) |

Implementation: polls the database every 1 second. If a matching email is found, returns it immediately. If timeout expires, returns `204 No Content`.

```json
// Success: email found (200)
{
  "email": {
    "id": "...",
    "from": "app@mycompany.com",
    "subject": "Verify your email",
    "body_html": "...",
    "body_text": "...",
    "received_at": "2026-03-15T10:30:05Z",
    "attachments": [...]
  }
}

// Timeout: no matching email (204 No Content)
// Empty response body
```

Future optimization: replace polling with ActionCable pub/sub via event store subscriptions. For now, 1-second polling is simple and adequate for a dev tool.

#### `POST /admin/projects`

Create a new project.

```json
// Request
{
  "project": {
    "name": "My SaaS App",
    "slug": "my-saas-app",
    "default_ttl_hours": 48,
    "max_inbox_count": 200
  }
}

// Response (201)
{
  "project": {
    "id": "...",
    "name": "My SaaS App",
    "slug": "my-saas-app",
    "default_ttl_hours": 48,
    "max_inbox_count": 200,
    "inbox_count": 0,
    "created_at": "2026-03-15T10:00:00Z"
  }
}
```

#### `POST /admin/projects/:id/api_keys`

Issue a new API key. The plaintext token is returned **once** in this response and never stored.

```json
// Request
{
  "api_key": {
    "label": "CI pipeline"
  }
}

// Response (201)
{
  "api_key": {
    "id": "...",
    "label": "CI pipeline",
    "token": "a1b2c3d4e5f6...64chars...",
    "token_prefix": "a1b2c3d4",
    "created_at": "2026-03-15T10:00:00Z"
  }
}
```

Subsequent `GET /admin/projects/:id/api_keys` returns keys **without** the `token` field — only `id`, `label`, `token_prefix`, `last_used_at`, `created_at`.

---

## Architecture

### Layer Mapping

Following spec 001's architecture rules:

```
HTTP Request
  │
  ▼
Controller (thin)
  ├── Command? → ApplicationService → Aggregate → EventStore → Repository
  └── Query?  → ReadModel (AR query) → Serializer → JSON
```

### Read Models

Read models are query-optimized modules in `app/read_models/` that query ActiveRecord directly (rule R1). They return plain hashes or structs — no domain entities.

```ruby
# app/read_models/inbox_list.rb
module Inboxed
  module ReadModels
    class InboxList
      def self.for_project(project_id, limit:, after: nil)
        scope = InboxRecord
          .where(project_id: project_id)
          .select(:id, :address, :email_count, :created_at)

        scope = apply_cursor(scope, after) if after
        records = scope.order(created_at: :desc, id: :desc).limit(limit + 1).to_a

        {
          records: records.first(limit),
          has_more: records.size > limit,
          total_count: InboxRecord.where(project_id: project_id).count
        }
      end
    end
  end
end
```

```ruby
# app/read_models/email_list.rb
module Inboxed
  module ReadModels
    class EmailList
      def self.for_inbox(inbox_id, limit:, after: nil)
        scope = EmailRecord
          .where(inbox_id: inbox_id)
          .select(:id, :from_address, :to_addresses, :subject, :body_text,
                  :source_type, :received_at)
          .left_joins(:attachments)
          .group(:id)
          .select("COUNT(attachments.id) AS attachment_count")

        scope = apply_cursor(scope, after) if after
        records = scope.order(received_at: :desc, id: :desc).limit(limit + 1).to_a

        {
          records: records.first(limit),
          has_more: records.size > limit,
          total_count: EmailRecord.where(inbox_id: inbox_id).count
        }
      end
    end
  end
end
```

```ruby
# app/read_models/email_detail.rb
module Inboxed
  module ReadModels
    class EmailDetail
      def self.find(email_id)
        EmailRecord.includes(:attachments).find(email_id)
      end
    end
  end
end
```

```ruby
# app/read_models/email_search.rb
module Inboxed
  module ReadModels
    class EmailSearch
      def self.search(project_id, query:, limit:, after: nil)
        sanitized = ActiveRecord::Base.sanitize_sql_like(query)
        tsquery = Arel.sql(
          ActiveRecord::Base.sanitize_sql_array(
            ["plainto_tsquery('simple', ?)", query]
          )
        )

        scope = EmailRecord
          .joins(inbox: :project)
          .where(inboxes: { project_id: project_id })
          .where(
            "to_tsvector('simple', coalesce(emails.subject, '') || ' ' || coalesce(emails.body_text, '')) @@ plainto_tsquery('simple', ?)",
            query
          )
          .select(
            "emails.*",
            "inboxes.address AS inbox_address",
            "ts_rank(to_tsvector('simple', coalesce(emails.subject, '') || ' ' || coalesce(emails.body_text, '')), plainto_tsquery('simple', #{ActiveRecord::Base.connection.quote(query)})) AS relevance"
          )

        scope = apply_cursor(scope, after) if after
        records = scope.order(Arel.sql("relevance DESC"), id: :desc).limit(limit + 1).to_a

        {
          records: records.first(limit),
          has_more: records.size > limit,
          total_count: scope.count
        }
      end
    end
  end
end
```

### Application Services (Commands)

New services for write operations:

```ruby
# app/application/services/create_project.rb
module Inboxed
  module Services
    class CreateProject
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(name:, slug:, default_ttl_hours: nil, max_inbox_count: 100)
        id = SecureRandom.uuid

        project = Aggregates::Project.new(id)
        project.create(name: name, slug: slug)

        @event_store.publish(
          stream: "Project-#{id}",
          events: project.pending_events
        )

        ProjectRecord.create!(
          id: id,
          name: name,
          slug: slug,
          default_ttl_hours: default_ttl_hours,
          max_inbox_count: max_inbox_count
        )

        project.clear_pending_events
        id
      end
    end
  end
end
```

```ruby
# app/application/services/issue_api_key.rb
module Inboxed
  module Services
    class IssueApiKey
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(project_id:, label: nil)
        token = SecureRandom.hex(32)
        id = SecureRandom.uuid

        project = @event_store.load_aggregate(Aggregates::Project, project_id)
        project.issue_api_key(id: id, label: label, token_digest: BCrypt::Password.create(token))

        @event_store.publish(
          stream: "Project-#{project_id}",
          events: project.pending_events
        )

        ApiKeyRecord.create!(
          id: id,
          project_id: project_id,
          token_prefix: token[0..7],
          token_digest: BCrypt::Password.create(token),
          label: label
        )

        project.clear_pending_events
        { id: id, token: token, token_prefix: token[0..7], label: label }
      end
    end
  end
end
```

```ruby
# app/application/services/delete_inbox.rb
module Inboxed
  module Services
    class DeleteInbox
      def call(inbox_id:)
        inbox = InboxRecord.find(inbox_id)
        AttachmentRecord.joins(:email).where(emails: { inbox_id: inbox_id }).delete_all
        EmailRecord.where(inbox_id: inbox_id).delete_all
        inbox.destroy!
      end
    end
  end
end
```

```ruby
# app/application/services/purge_inbox.rb
module Inboxed
  module Services
    class PurgeInbox
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(inbox_id:)
        email_count = EmailRecord.where(inbox_id: inbox_id).count
        AttachmentRecord.joins(:email).where(emails: { inbox_id: inbox_id }).delete_all
        EmailRecord.where(inbox_id: inbox_id).delete_all
        InboxRecord.where(id: inbox_id).update_all(email_count: 0)

        inbox_aggregate = @event_store.load_aggregate(Aggregates::Inbox, inbox_id)
        event = Events::InboxPurged.new(data: { inbox_id: inbox_id, deleted_count: email_count })
        @event_store.publish(stream: "Inbox-#{inbox_id}", events: [event])

        email_count
      end
    end
  end
end
```

```ruby
# app/application/services/delete_email.rb
module Inboxed
  module Services
    class DeleteEmail
      def initialize(event_store: EventStore::Store)
        @event_store = event_store
      end

      def call(email_id:)
        email = EmailRecord.find(email_id)
        inbox_id = email.inbox_id

        AttachmentRecord.where(email_id: email_id).delete_all
        email.destroy!
        InboxRecord.where(id: inbox_id).update_counters(email_count: -1)

        inbox_aggregate = @event_store.load_aggregate(Aggregates::Inbox, inbox_id)
        inbox_aggregate.delete_email(email_id: email_id)
        @event_store.publish(
          stream: "Inbox-#{inbox_id}",
          events: inbox_aggregate.pending_events
        )
        inbox_aggregate.clear_pending_events
      end
    end
  end
end
```

```ruby
# app/application/services/wait_for_email.rb
module Inboxed
  module Services
    class WaitForEmail
      MAX_TIMEOUT = 30
      POLL_INTERVAL = 1

      def call(project_id:, inbox_address:, subject_pattern: nil, timeout_seconds: 30)
        timeout = [timeout_seconds.to_i, MAX_TIMEOUT].min
        cutoff = Time.current
        deadline = Time.current + timeout

        loop do
          email = find_matching_email(project_id, inbox_address, subject_pattern, cutoff)
          return email if email
          break if Time.current >= deadline
          sleep POLL_INTERVAL
        end

        nil
      end

      private

      def find_matching_email(project_id, inbox_address, subject_pattern, since)
        scope = EmailRecord
          .joins(:inbox)
          .where(inboxes: { project_id: project_id, address: inbox_address })
          .where("emails.received_at >= ?", since)
          .order(received_at: :desc)

        if subject_pattern.present?
          scope = scope.where("emails.subject ~ ?", subject_pattern)
        end

        scope.includes(:attachments).first
      end
    end
  end
end
```

### Serializers

Serializers live in `app/serializers/` and handle JSON structure per ADR-008:

```ruby
# app/serializers/base_serializer.rb
module Inboxed
  module Serializers
    class BaseSerializer
      def self.render(resource, **options)
        new(resource, **options).as_json
      end
    end
  end
end
```

```ruby
# app/serializers/email_list_serializer.rb
module Inboxed
  module Serializers
    class EmailListSerializer < BaseSerializer
      def initialize(record)
        @record = record
      end

      def as_json
        {
          id: @record.id,
          from: @record.from_address,
          to: @record.to_addresses,
          subject: @record.subject,
          preview: (@record.body_text || "").truncate(200),
          has_attachments: (@record.try(:attachment_count) || 0) > 0,
          attachment_count: @record.try(:attachment_count) || 0,
          source_type: @record.source_type,
          received_at: @record.received_at.iso8601
        }
      end
    end
  end
end
```

```ruby
# app/serializers/email_detail_serializer.rb
module Inboxed
  module Serializers
    class EmailDetailSerializer < BaseSerializer
      def initialize(record)
        @record = record
      end

      def as_json
        {
          id: @record.id,
          inbox_id: @record.inbox_id,
          from: @record.from_address,
          to: @record.to_addresses,
          cc: @record.cc_addresses,
          subject: @record.subject,
          body_html: @record.body_html,
          body_text: @record.body_text,
          raw_headers: @record.raw_headers,
          source_type: @record.source_type,
          received_at: @record.received_at.iso8601,
          expires_at: @record.expires_at.iso8601,
          attachments: @record.attachments.map { |a| attachment_json(a) }
        }
      end

      private

      def attachment_json(att)
        {
          id: att.id,
          filename: att.filename,
          content_type: att.content_type,
          size_bytes: att.size_bytes,
          inline: att.inline,
          download_url: "/api/v1/attachments/#{att.id}/download"
        }
      end
    end
  end
end
```

### Controller Examples

```ruby
# app/controllers/api/v1/inboxes_controller.rb
module Api
  module V1
    class InboxesController < BaseController
      def index
        result = Inboxed::ReadModels::InboxList.for_project(
          @current_project.id,
          limit: pagination_limit,
          after: params[:after]
        )

        render json: {
          inboxes: result[:records].map { |r| serialize_inbox(r) },
          pagination: pagination_meta(result)
        }
      end

      def show
        inbox = InboxRecord.find_by!(id: params[:id], project_id: @current_project.id)
        render json: { inbox: serialize_inbox(inbox) }
      end

      def destroy
        inbox = InboxRecord.find_by!(id: params[:id], project_id: @current_project.id)
        Inboxed::Services::DeleteInbox.new.call(inbox_id: inbox.id)
        head :no_content
      end

      private

      def serialize_inbox(record)
        {
          id: record.id,
          address: record.address,
          email_count: record.email_count,
          created_at: record.created_at.iso8601
        }
      end
    end
  end
end
```

```ruby
# app/controllers/api/v1/emails_controller.rb
module Api
  module V1
    class EmailsController < BaseController
      def index
        inbox = InboxRecord.find_by!(id: params[:inbox_id], project_id: @current_project.id)

        result = Inboxed::ReadModels::EmailList.for_inbox(
          inbox.id,
          limit: pagination_limit,
          after: params[:after]
        )

        render json: {
          emails: result[:records].map { |r| Inboxed::Serializers::EmailListSerializer.render(r) },
          pagination: pagination_meta(result)
        }
      end

      def show
        email = find_scoped_email(params[:id])
        render json: { email: Inboxed::Serializers::EmailDetailSerializer.render(email) }
      end

      def raw
        email = find_scoped_email(params[:id])
        send_data email.raw_source,
                  type: "text/plain; charset=utf-8",
                  disposition: "inline; filename=\"email.eml\""
      end

      def destroy
        email = find_scoped_email(params[:id])
        Inboxed::Services::DeleteEmail.new.call(email_id: email.id)
        head :no_content
      end

      def purge
        inbox = InboxRecord.find_by!(id: params[:inbox_id], project_id: @current_project.id)
        deleted = Inboxed::Services::PurgeInbox.new.call(inbox_id: inbox.id)
        render json: { deleted_count: deleted }
      end

      def wait
        result = Inboxed::Services::WaitForEmail.new.call(
          project_id: @current_project.id,
          inbox_address: params[:inbox_address],
          subject_pattern: params[:subject_pattern],
          timeout_seconds: params[:timeout_seconds]
        )

        if result
          render json: { email: Inboxed::Serializers::EmailDetailSerializer.render(result) }
        else
          head :no_content
        end
      end

      private

      def find_scoped_email(id)
        EmailRecord
          .includes(:attachments)
          .joins(:inbox)
          .where(inboxes: { project_id: @current_project.id })
          .find(id)
      end
    end
  end
end
```

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Admin endpoints
  namespace :admin do
    get "status", to: "status#show"
    resources :projects, only: [:index, :show, :create, :update, :destroy] do
      resources :api_keys, only: [:index, :create]
    end
    resources :api_keys, only: [:update, :destroy]
  end

  # API v1
  namespace :api do
    namespace :v1 do
      get "status", to: "status#show"

      resources :inboxes, only: [:index, :show, :destroy] do
        resources :emails, only: [:index]
        delete "emails", to: "emails#purge", on: :member
      end

      resources :emails, only: [:show, :destroy] do
        get "raw", on: :member
        resources :attachments, only: [:index]
      end

      resources :attachments, only: [] do
        get "download", on: :member
      end

      get "search", to: "search#show"
      post "emails/wait", to: "emails#wait"
    end
  end
end
```

### Shared Concerns

```ruby
# app/controllers/concerns/paginatable.rb
module Paginatable
  extend ActiveSupport::Concern

  private

  def pagination_limit
    [params.fetch(:limit, 20).to_i, 100].min
  end

  def pagination_meta(result)
    last_record = result[:records].last
    {
      has_more: result[:has_more],
      next_cursor: result[:has_more] ? encode_cursor(last_record) : nil,
      total_count: result[:total_count]
    }
  end

  def encode_cursor(record)
    return nil unless record
    sort_key = record.try(:received_at) || record.created_at
    Base64.urlsafe_encode64({ t: sort_key.iso8601(6), id: record.id }.to_json)
  end

  def decode_cursor(cursor)
    return nil unless cursor
    JSON.parse(Base64.urlsafe_decode64(cursor)).symbolize_keys
  end
end
```

```ruby
# app/controllers/concerns/error_renderable.rb
module ErrorRenderable
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
    rescue_from ActionController::ParameterMissing, with: :render_bad_request
  end

  private

  def render_unauthorized(detail = "Authentication required")
    render json: {
      type: "https://docs.inboxed.dev/errors/unauthorized",
      title: "Unauthorized",
      detail: detail,
      status: 401
    }, status: :unauthorized, content_type: "application/problem+json"
  end

  def render_not_found(exception)
    render json: {
      type: "https://docs.inboxed.dev/errors/not-found",
      title: "Resource not found",
      detail: exception.message,
      status: 404,
      instance: request.path
    }, status: :not_found, content_type: "application/problem+json"
  end

  def render_validation_error(exception)
    errors = exception.record.errors.map { |e| { field: e.attribute, message: e.message } }
    render json: {
      type: "https://docs.inboxed.dev/errors/validation-error",
      title: "Validation failed",
      detail: "One or more request parameters are invalid.",
      status: 422,
      errors: errors
    }, status: :unprocessable_entity, content_type: "application/problem+json"
  end

  def render_bad_request(exception)
    render json: {
      type: "https://docs.inboxed.dev/errors/bad-request",
      title: "Bad request",
      detail: exception.message,
      status: 400
    }, status: :bad_request, content_type: "application/problem+json"
  end
end
```

### Correlation IDs

Every API request generates a correlation ID that flows through the event store:

```ruby
# app/controllers/api/v1/base_controller.rb
before_action :set_correlation_id

def set_correlation_id
  @correlation_id = request.headers["X-Correlation-ID"] || SecureRandom.uuid
  response.set_header("X-Correlation-ID", @correlation_id)
end
```

Services pass `@correlation_id` to `event_store.publish(metadata: { correlation_id: @correlation_id })`.

---

## API Documentation (OpenAPI + Redocly)

### OpenAPI Spec

Maintain an OpenAPI 3.1 spec at `docs/api/openapi.yaml` as the single source of truth for the API contract.

```yaml
# docs/api/openapi.yaml
openapi: "3.1.0"
info:
  title: Inboxed API
  version: "1.0.0"
  description: REST API for Inboxed — the developer email testing tool.
  contact:
    url: https://github.com/inboxed/inboxed
servers:
  - url: http://localhost:3000
    description: Development
paths:
  /api/v1/inboxes:
    get:
      summary: List inboxes
      tags: [Inboxes]
      security:
        - apiKey: []
      parameters:
        - $ref: "#/components/parameters/limit"
        - $ref: "#/components/parameters/after"
      responses:
        "200":
          description: List of inboxes
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/InboxListResponse"
  # ... remaining paths
components:
  securitySchemes:
    apiKey:
      type: http
      scheme: bearer
      description: Project API key
    adminToken:
      type: http
      scheme: bearer
      description: Admin token (INBOXED_ADMIN_TOKEN)
  parameters:
    limit:
      name: limit
      in: query
      schema: { type: integer, default: 20, maximum: 100 }
    after:
      name: after
      in: query
      schema: { type: string }
      description: Cursor for pagination
  schemas:
    InboxListResponse:
      type: object
      properties:
        inboxes:
          type: array
          items: { $ref: "#/components/schemas/Inbox" }
        pagination:
          $ref: "#/components/schemas/Pagination"
    # ... remaining schemas
```

### Redocly CLI Integration

Add `@redocly/cli` to the project for linting, bundling, and previewing the API docs:

```json
// package.json (root or docs/api/)
{
  "scripts": {
    "docs:lint": "redocly lint docs/api/openapi.yaml",
    "docs:preview": "redocly preview-docs docs/api/openapi.yaml",
    "docs:build": "redocly build-docs docs/api/openapi.yaml -o docs/api/index.html"
  },
  "devDependencies": {
    "@redocly/cli": "^1.34"
  }
}
```

```yaml
# redocly.yaml (project root)
extends:
  - recommended
rules:
  operation-operationId: error
  tag-description: warn
  no-unused-components: warn
theme:
  openapi:
    theme:
      colors:
        primary:
          main: "#39FF14"
        text:
          primary: "#E8F0E9"
      typography:
        fontFamily: "Inter, sans-serif"
        code:
          fontFamily: "JetBrains Mono, monospace"
```

The built HTML docs can be served as a static page at `/docs` by Caddy in production, or previewed locally with `npm run docs:preview`.

### CI Integration

Add an OpenAPI lint step to GitHub Actions:

```yaml
# In .github/workflows/ci.yml
api-docs:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with: { node-version: 22 }
    - run: npm ci
    - run: npm run docs:lint
```

---

## Rate Limiting

See [ADR-010](../adrs/010-rate-limiting.md) for the full decision record.

### Setup

```ruby
# Gemfile
gem "rack-attack"
```

```ruby
# config/initializers/rack_attack.rb
# See ADR-010 for full configuration
```

Rate limit headers on every response:

```ruby
# app/controllers/api/v1/base_controller.rb
after_action :set_rate_limit_headers

def set_rate_limit_headers
  # Rack::Attack exposes matched data via request.env
  matched = request.env["rack.attack.matched"]
  return unless matched

  limit = request.env["rack.attack.match_data"][:limit]
  remaining = limit - request.env["rack.attack.match_data"][:count]
  period = request.env["rack.attack.match_data"][:period]

  response.set_header("X-RateLimit-Limit", limit.to_s)
  response.set_header("X-RateLimit-Remaining", [remaining, 0].max.to_s)
  response.set_header("X-RateLimit-Reset", (Time.current.to_i + period).to_s)
end
```

---

## Technical Decisions

### Decision: Read models for queries, services for commands

- **Options:** (A) All operations through aggregates and repositories. (B) Split: commands through services/aggregates, queries through read models.
- **Chosen:** B — CQRS-lite
- **Why:** Loading an aggregate from the event store for a simple list query is wasteful. Read models query AR directly, shaped exactly for the response. Commands still go through the domain layer to enforce invariants and publish events.
- **Trade-offs:** Two paths for data access. Mitigated by clear rule: `if it changes state → service, if it reads → read model`.

### Decision: Long-poll with DB polling for wait endpoint

- **Options:** (A) WebSocket/ActionCable push. (B) Database polling every 1s. (C) Event store subscription with in-memory queue.
- **Chosen:** B — DB polling
- **Why:** Simplest implementation. The wait endpoint is called infrequently (once per test). 1 lightweight `SELECT` per second for up to 30s is negligible load on a dev tool database. ActionCable is reserved for the dashboard's real-time features (Phase 3).
- **Trade-offs:** 0-1s latency after email arrives. Acceptable for test automation. Can be optimized to ActionCable push in the future without changing the API contract.

### Decision: OpenAPI spec maintained manually

- **Options:** (A) Auto-generate from Rails routes/serializers (rswag). (B) Write OpenAPI YAML manually. (C) Skip API docs.
- **Chosen:** B — manual OpenAPI spec
- **Why:** The API surface is small (~15 endpoints). Manual spec is the source of truth, validated by Redocly lint in CI. Auto-generation requires heavy annotations on controllers and often produces noisy specs. Manual spec lets us write clear descriptions, examples, and group endpoints logically.
- **Trade-offs:** Must keep spec in sync with implementation. Mitigated by request specs that test the actual responses against expected shapes.

### Decision: Serializers as plain Ruby objects

- **Options:** (A) Use `active_model_serializers` or `jsonapi-serializer` gem. (B) Plain Ruby serializer classes. (C) `jbuilder` templates.
- **Chosen:** B — plain Ruby
- **Why:** No gem dependency for a simple task. Each serializer is a class with `as_json` that returns a hash. Easy to test, easy to understand, no magic. The response envelope pattern (ADR-008) doesn't map cleanly to AMS conventions.
- **Trade-offs:** No automatic relationship handling. Not needed — our resources are shallow (1 level of nesting for email→attachments).

---

## Implementation Plan

### Step 1: Add gems and configuration

Add `rack-attack` to Gemfile. Create initializers for Rack::Attack and CORS (update allowed origins if needed).

### Step 2: Base controller infrastructure

1. Complete API key validation in `Api::V1::BaseController` (replace TODO)
2. Add `Paginatable` concern
3. Add `ErrorRenderable` concern
4. Add correlation ID handling
5. Add rate limit header `after_action`

### Step 3: Read models

Create read models in `app/read_models/`:
1. `InboxList` — for project inbox listing
2. `EmailList` — for inbox email listing with attachment count
3. `EmailDetail` — for single email with attachments
4. `EmailSearch` — for full-text search with relevance ranking

### Step 4: Serializers

Create serializers in `app/serializers/`:
1. `EmailListSerializer` — lightweight email for lists
2. `EmailDetailSerializer` — full email with attachments
3. `InboxSerializer` — inbox with stats
4. `ProjectSerializer` — project details
5. `ApiKeySerializer` — API key (with/without token)

### Step 5: Application services (commands)

Create services in `app/application/services/`:
1. `CreateProject`
2. `UpdateProject`
3. `DeleteProject`
4. `IssueApiKey`
5. `RevokeApiKey`
6. `DeleteInbox`
7. `PurgeInbox`
8. `DeleteEmail`
9. `WaitForEmail`

### Step 6: Admin controllers

Implement admin controllers:
1. `Admin::ProjectsController` — CRUD
2. `Admin::ApiKeysController` — issue, list, update, revoke

### Step 7: API v1 controllers

Implement API v1 controllers:
1. `Api::V1::InboxesController` — index, show, destroy
2. `Api::V1::EmailsController` — index, show, raw, destroy, purge, wait
3. `Api::V1::AttachmentsController` — index, download
4. `Api::V1::SearchController` — show

### Step 8: Routes

Update `config/routes.rb` with all new endpoints.

### Step 9: Rate limiting

Configure Rack::Attack per ADR-010.

### Step 10: OpenAPI spec & Redocly

1. Write `docs/api/openapi.yaml` covering all endpoints
2. Add `@redocly/cli` to devDependencies
3. Add `redocly.yaml` config with Inboxed branding
4. Add `docs:lint`, `docs:preview`, `docs:build` scripts
5. Add API docs lint step to CI

### Step 11: Request specs

Write request specs in `spec/requests/`:

| Spec file | Covers |
|-----------|--------|
| `admin/projects_spec.rb` | Project CRUD, validation errors, auth |
| `admin/api_keys_spec.rb` | Issue, list, update, revoke, token visibility |
| `api/v1/inboxes_spec.rb` | List, show, destroy, project scoping |
| `api/v1/emails_spec.rb` | List, show, raw, destroy, purge, pagination |
| `api/v1/attachments_spec.rb` | List, download, binary content |
| `api/v1/search_spec.rb` | Full-text search, relevance, empty results |
| `api/v1/wait_spec.rb` | Long-poll success, timeout, pattern matching |

Each spec tests:
- Happy path
- Authentication required (401)
- Project scoping (can't access other project's resources)
- Not found (404)
- Pagination (cursors, limits, `has_more`)
- Error format (RFC 7807 compliance)

### Step 12: Update seed/setup task

Extend `inboxed:setup` rake task to print API endpoint examples:

```
API Base: http://localhost:3000/api/v1
Auth:     Authorization: Bearer <token>

Try:
  curl -H "Authorization: Bearer <token>" http://localhost:3000/api/v1/inboxes
```

---

## Exit Criteria

- [ ] API key validation fully working — invalid key returns 401, valid key scopes to project
- [ ] Admin endpoints: full CRUD on projects and API keys
- [ ] `GET /api/v1/inboxes` returns paginated inbox list for current project
- [ ] `GET /api/v1/inboxes/:id/emails` returns paginated email list with preview and attachment count
- [ ] `GET /api/v1/emails/:id` returns full email detail with attachments
- [ ] `GET /api/v1/emails/:id/raw` returns raw MIME source as `text/plain`
- [ ] `GET /api/v1/attachments/:id/download` returns binary attachment
- [ ] `GET /api/v1/search?q=...` returns full-text search results with relevance
- [ ] `POST /api/v1/emails/wait` blocks until matching email or timeout
- [ ] All error responses follow RFC 7807 with `application/problem+json` content type
- [ ] Cursor pagination works correctly — no duplicates or gaps under concurrent inserts
- [ ] Rate limiting active with `X-RateLimit-*` headers on every response
- [ ] Project scoping enforced — API key can only access its own project's resources
- [ ] Correlation IDs flow through request → events → response header
- [ ] OpenAPI spec at `docs/api/openapi.yaml` covers all endpoints, passes Redocly lint
- [ ] **End-to-end:** send email via SMTP → `POST /api/v1/emails/wait` returns it → `GET /api/v1/emails/:id` shows full detail → `GET /api/v1/attachments/:id/download` returns attachment
- [ ] All request specs pass
- [ ] All existing tests still pass
- [ ] CI green (including API docs lint)

---

## Open Questions

1. **CORS origins** — Currently `DASHBOARD_URL` is the only allowed origin. Should the API support configurable CORS for SDK consumers running in browsers? **Recommendation:** keep `DASHBOARD_URL` for now. SDK consumers use server-side HTTP clients, not browsers. Add configurable CORS in Phase 5 if browser-based test helpers need it.

2. **Bulk operations** — Should we support `DELETE /api/v1/inboxes/:id/emails` with a filter (e.g., delete emails older than X)? **Recommendation:** defer. The purge endpoint covers the common case. Filtered bulk deletes can be added in Phase 7.

3. **Webhook on email received** — The wait endpoint is synchronous. Should we offer a webhook alternative? **Recommendation:** defer to Phase 7 (in the ROADMAP backlog). The wait endpoint covers the test automation use case. Webhooks add complexity (delivery guarantees, retry logic, signature verification).
