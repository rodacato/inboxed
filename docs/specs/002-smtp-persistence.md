# 002 — SMTP Reception & Email Persistence

> Receive emails via SMTP, parse MIME, persist to PostgreSQL through the event store, and clean up expired messages.

**Phase:** Phase 1 (SMTP + Persistence)
**Status:** implemented
**Release:** —
**Depends on:** [001-architecture](001-architecture.md)

---

## Objective

Build the core engine of Inboxed: an SMTP server that receives emails sent by applications under test, parses their MIME content, persists them through the domain layer and event store, and provides TTL-based cleanup. By the end of this spec, a developer can point their app's SMTP config at Inboxed and verify captured emails in PostgreSQL.

No REST API, no dashboard integration, no MCP tools. Just reliable email reception and storage.

---

## Context

### Current State

- Foundation (spec 000) and architecture (spec 001) complete
- Event store Phase 1 implemented and tested (publish, subscribe, replay, correlation)
- Domain type system in place (`Inboxed::Types` with Email, UUID, StreamName, etc.)
- Rails API running with two auth strategies (API key + admin token)
- No domain entities, aggregates, or business logic yet

### What This Spec Delivers

1. **Data models** — Project, Inbox, Email, Attachment, ApiKey as domain entities + AR persistence
2. **SMTP server** — `midi-smtp-server` receiving emails with AUTH and TLS
3. **MIME parsing** — Extract HTML, plain text, attachments, inline images from raw email
4. **Event-sourced persistence** — Emails stored through aggregates and the event store
5. **Background cleanup** — Solid Queue job deleting expired emails by project TTL

### Constraints

- Domain layer remains pure Ruby — no Rails, no ActiveRecord
- SMTP server runs as a separate process (not inside Puma)
- No open relay — reject mail for unregistered projects/API keys
- Attachments stored in PostgreSQL (not filesystem) for simplicity — see [ADR-006](../adrs/006-attachment-storage.md)
- Event store Phase 2 (snapshots) implemented alongside this spec per ADR-002

---

## Data Model

### Domain Entities & Value Objects

```
Project (Aggregate Root)
├── name: NonEmpty
├── slug: NonEmpty (unique, URL-safe)
├── default_ttl_hours: Integer.optional (nil = use ENV/global default)
├── max_inbox_count: Integer (default: 100)
├── created_at: DateTime
│
├── ApiKey (Entity, child of Project)
│   ├── id: UUID
│   ├── token_digest: NonEmpty (bcrypt hash)
│   ├── label: String.optional
│   ├── last_used_at: DateTime.optional
│   └── created_at: DateTime
│
└── Inbox (Aggregate Root)
    ├── id: UUID
    ├── project_id: UUID
    ├── address: EmailAddress (e.g. "test@mail.inboxed.dev")
    ├── email_count: Integer
    ├── created_at: DateTime
    │
    └── Email (Entity, child of Inbox)
        ├── id: UUID
        ├── inbox_id: UUID
        ├── from: EmailAddress
        ├── to: Array<EmailAddress>
        ├── cc: Array<EmailAddress>
        ├── subject: String
        ├── body_html: String.optional
        ├── body_text: String.optional
        ├── raw_headers: Hash
        ├── raw_source: String (full MIME source)
        ├── source_type: String (inbound | relay)
        ├── received_at: DateTime
        ├── expires_at: DateTime
        │
        └── Attachment (Value Object)
            ├── filename: String
            ├── content_type: String
            ├── size_bytes: Integer
            ├── content: Binary (stored in DB)
            └── content_id: String.optional (for inline images)
```

### Value Objects

```ruby
# app/domain/value_objects/email_address.rb
class Inboxed::ValueObjects::EmailAddress < Dry::Struct
  attribute :local,  Inboxed::Types::NonEmpty   # "test"
  attribute :domain, Inboxed::Types::NonEmpty   # "mail.inboxed.dev"

  def to_s = "#{local}@#{domain}"
  def self.parse(string) = # splits on @
end

# app/domain/value_objects/message_body.rb
class Inboxed::ValueObjects::MessageBody < Dry::Struct
  attribute :html, Inboxed::Types::String.optional.default(nil)
  attribute :text, Inboxed::Types::String.optional.default(nil)

  def empty? = html.nil? && text.nil?
  def preview(length: 200) = (text || html&.gsub(/<[^>]+>/, '') || '').truncate(length)
end

# app/domain/value_objects/attachment_info.rb
class Inboxed::ValueObjects::AttachmentInfo < Dry::Struct
  attribute :filename,    Inboxed::Types::NonEmpty
  attribute :content_type, Inboxed::Types::NonEmpty
  attribute :size_bytes,  Inboxed::Types::Coercible::Integer
  attribute :content_id,  Inboxed::Types::String.optional.default(nil)
  attribute :inline,      Inboxed::Types::Bool.default(false)
end
```

### Domain Events

```ruby
# app/domain/events/
Inboxed::Events::ProjectCreated     # { project_id, name, slug }
Inboxed::Events::ApiKeyIssued       # { project_id, api_key_id, label }
Inboxed::Events::InboxCreated       # { inbox_id, project_id, address }
Inboxed::Events::EmailReceived      # { email_id, inbox_id, from, to, subject, source_type }
Inboxed::Events::EmailDeleted       # { email_id, inbox_id }
Inboxed::Events::InboxPurged        # { inbox_id, deleted_count }
```

### Aggregates

**InboxAggregate** — the primary aggregate root for email reception:

```ruby
class Inboxed::Aggregates::Inbox
  include Inboxed::EventStore::AggregateRoot

  attr_reader :id, :project_id, :address, :email_count, :emails

  def receive_email(id:, from:, to:, subject:, body:, attachments:, raw_source:, source_type:, expires_at:)
    # Invariant: email_count < project max (enforced here, not in service)
    apply EmailReceived.new(data: { ... })
  end

  def delete_email(email_id:)
    apply EmailDeleted.new(data: { email_id:, inbox_id: id })
  end

  on(EmailReceived) do |event|
    @email_count += 1
  end

  on(EmailDeleted) do |event|
    @email_count -= 1
  end
end
```

**ProjectAggregate** — manages project lifecycle and API keys:

```ruby
class Inboxed::Aggregates::Project
  include Inboxed::EventStore::AggregateRoot

  def issue_api_key(id:, label:, token_digest:)
    apply ApiKeyIssued.new(data: { project_id: @id, api_key_id: id, label:, token_digest: })
  end
end
```

---

## Database Schema

### Migrations

```ruby
# db/migrate/xxx_create_projects.rb
create_table :projects, id: :uuid do |t|
  t.string  :name,              null: false
  t.string  :slug,              null: false
  t.integer :default_ttl_hours              # nil = use ENV/global default (168h)
  t.integer :max_inbox_count,   null: false, default: 100
  t.timestamps
end

add_index :projects, :slug, unique: true
```

```ruby
# db/migrate/xxx_create_api_keys.rb
create_table :api_keys, id: :uuid do |t|
  t.references :project, type: :uuid, null: false, foreign_key: true
  t.string     :token_digest,  null: false
  t.string     :token_prefix,  null: false  # first 8 chars for identification
  t.string     :label
  t.datetime   :last_used_at
  t.timestamps
end

add_index :api_keys, :token_prefix
```

```ruby
# db/migrate/xxx_create_inboxes.rb
create_table :inboxes, id: :uuid do |t|
  t.references :project, type: :uuid, null: false, foreign_key: true
  t.string     :address,     null: false  # full email address
  t.integer    :email_count, null: false, default: 0
  t.timestamps
end

add_index :inboxes, :address, unique: true
add_index :inboxes, [:project_id, :created_at]
```

```ruby
# db/migrate/xxx_create_emails.rb
create_table :emails, id: :uuid do |t|
  t.references :inbox,       type: :uuid, null: false, foreign_key: true
  t.string     :from_address, null: false
  t.string     :to_addresses, null: false, array: true, default: []
  t.string     :cc_addresses, null: false, array: true, default: []
  t.string     :subject
  t.text       :body_html
  t.text       :body_text
  t.jsonb      :raw_headers,  null: false, default: {}
  t.text       :raw_source,   null: false
  t.string     :source_type,  null: false, default: 'relay'
  t.datetime   :received_at,  null: false
  t.datetime   :expires_at,   null: false
  t.timestamps
end

add_index :emails, [:inbox_id, :received_at]
add_index :emails, :expires_at
add_index :emails, :from_address
add_index :emails, "to_tsvector('simple', coalesce(subject, '') || ' ' || coalesce(body_text, ''))",
          using: :gin, name: 'idx_emails_fulltext'
```

```ruby
# db/migrate/xxx_create_attachments.rb
create_table :attachments, id: :uuid do |t|
  t.references :email,        type: :uuid, null: false, foreign_key: true
  t.string     :filename,     null: false
  t.string     :content_type, null: false
  t.integer    :size_bytes,   null: false
  t.binary     :content,      null: false
  t.string     :content_id                   # for inline images (cid:)
  t.boolean    :inline,       null: false, default: false
  t.timestamps
end

add_index :attachments, :email_id
```

### Event Store Phase 2: Snapshots

Per ADR-002, implement snapshots alongside this spec:

```ruby
# db/migrate/xxx_create_snapshots.rb
create_table :snapshots do |t|
  t.string   :stream_name,     null: false
  t.integer  :stream_position, null: false
  t.string   :aggregate_type,  null: false
  t.integer  :schema_version,  null: false, default: 1
  t.jsonb    :state,           null: false
  t.datetime :created_at,      null: false, default: -> { "CURRENT_TIMESTAMP" }
end

add_index :snapshots, :stream_name, unique: true
```

---

## SMTP Server

### Architecture

See [ADR-007](../adrs/007-smtp-server-design.md) for the full decision record.

The SMTP server runs as a **separate process** alongside Puma, managed by Procfile:

```
web: bundle exec rails server -b 0.0.0.0 -p 3000
smtp: bundle exec rails runner "Inboxed::SmtpServer.start"
worker: bundle exec rails solid_queue:start
```

### Implementation

```ruby
# app/infrastructure/adapters/smtp_server.rb
module Inboxed
  class SmtpServer < MidiSmtpServer::Smtpd
    def initialize
      super(
        ports: smtp_ports,
        hosts: '0.0.0.0',
        max_processings: 4,
        auth_mode: :AUTH_REQUIRED,
        tls_mode: tls_mode,
        tls_cert_path: ENV['SMTP_TLS_CERT'],
        tls_key_path: ENV['SMTP_TLS_KEY'],
        logger: Rails.logger
      )
    end

    # Called on AUTH — validate API key
    def on_auth_event(ctx, authorization)
      api_key = authenticate_api_key(authorization[:password])
      raise MidiSmtpServer::Smtpd535Exception unless api_key
      ctx[:project] = api_key.project
      ctx[:api_key] = api_key
    end

    # Called on MAIL FROM
    def on_mail_from_event(ctx, mail_from)
      ctx[:envelope_from] = mail_from
    end

    # Called on RCPT TO — validate recipient domain
    def on_rcpt_to_event(ctx, rcpt_to)
      # Accept any address — inbox created on-demand
      ctx[:envelope_to] ||= []
      ctx[:envelope_to] << rcpt_to
    end

    # Called when full message is received (DATA complete)
    def on_message_data_event(ctx)
      ReceiveEmailJob.perform_later(
        project_id: ctx[:project].id,
        api_key_id: ctx[:api_key].id,
        envelope_from: ctx[:envelope_from],
        envelope_to: ctx[:envelope_to],
        raw_source: ctx[:message][:data],
        source_type: 'relay'
      )
    end

    private

    def smtp_ports
      ENV.fetch('SMTP_PORTS', '2525').split(',').map(&:to_i)
    end

    def tls_mode
      if ENV['SMTP_TLS_CERT'].present?
        :TLS_OPTIONAL
      else
        :TLS_FORBIDDEN
      end
    end

    def authenticate_api_key(token)
      return nil if token.blank?
      prefix = token[0..7]
      candidates = ApiKeyRecord.where(token_prefix: prefix).includes(:project)
      candidates.find { |k| BCrypt::Password.new(k.token_digest) == token }
    end
  end
end
```

### SMTP Ports & TLS Strategy

| Environment | Port | TLS | Auth |
|------------|------|-----|------|
| Development | 2525 | None (TLS_FORBIDDEN) | Required (API key) |
| Production | 587 | STARTTLS (TLS_OPTIONAL) | Required (API key) |
| Production | 465 | Implicit TLS (TLS_REQUIRED) | Required (API key) |

In development, TLS is disabled and a single port (2525) is used. In production, the operator provides TLS certificates via environment variables and can enable multiple ports.

### SMTP Authentication Flow

```
Client connects to port 2525
  → Server: 220 inboxed ESMTP ready
Client: EHLO myapp.test
  → Server: 250-AUTH PLAIN LOGIN
Client: AUTH PLAIN <base64(api_key)>
  → Server looks up API key by prefix, bcrypt-verifies
  → 235 Authentication successful (sets ctx[:project])
  → OR 535 Authentication failed
Client: MAIL FROM:<app@myapp.test>
Client: RCPT TO:<user@example.com>
  → Server accepts any recipient address
Client: DATA
  → Server receives full MIME message
  → Enqueues ReceiveEmailJob with project context
  → 250 OK
```

Key decisions:
- **Any recipient address is accepted** — Inboxed is a catch-all. Inboxes are created on-demand based on the RCPT TO address.
- **AUTH is always required** — no anonymous relay, even in development.
- **Processing is async** — DATA handler enqueues a Solid Queue job, doesn't block the SMTP session.

---

## MIME Parsing

### Service

```ruby
# app/application/services/parse_mime.rb
module Inboxed
  module Services
    class ParseMime
      Result = Dry::Struct.class do
        attribute :from,        Inboxed::Types::String
        attribute :to,          Inboxed::Types::Array.of(Inboxed::Types::String)
        attribute :cc,          Inboxed::Types::Array.of(Inboxed::Types::String).default([].freeze)
        attribute :subject,     Inboxed::Types::String.optional
        attribute :body_html,   Inboxed::Types::String.optional
        attribute :body_text,   Inboxed::Types::String.optional
        attribute :headers,     Inboxed::Types::Hash
        attribute :attachments, Inboxed::Types::Array
      end

      def call(raw_source)
        mail = Mail.new(raw_source)

        Result.new(
          from:        extract_from(mail),
          to:          extract_addresses(mail.to),
          cc:          extract_addresses(mail.cc),
          subject:     mail.subject,
          body_html:   extract_html(mail),
          body_text:   extract_text(mail),
          headers:     extract_headers(mail),
          attachments: extract_attachments(mail)
        )
      end

      private

      def extract_html(mail)
        return mail.html_part.decoded if mail.html_part
        return mail.body.decoded if mail.content_type&.include?('text/html')
        nil
      end

      def extract_text(mail)
        return mail.text_part.decoded if mail.text_part
        return mail.body.decoded if mail.content_type&.include?('text/plain')
        return mail.body.decoded unless mail.multipart?
        nil
      end

      def extract_attachments(mail)
        mail.attachments.map do |att|
          {
            filename: att.filename || 'unnamed',
            content_type: att.content_type.split(';').first,
            size_bytes: att.decoded.bytesize,
            content: att.decoded,
            content_id: att.content_id&.gsub(/[<>]/, ''),
            inline: att.content_disposition&.start_with?('inline') || false
          }
        end
      end

      def extract_from(mail)
        mail.from&.first || mail.header['From']&.to_s || 'unknown@unknown'
      end

      def extract_addresses(field)
        Array(field).map(&:to_s)
      end

      def extract_headers(mail)
        mail.header.fields.each_with_object({}) do |field, hash|
          hash[field.name] = field.value
        end
      end
    end
  end
end
```

### Handling Edge Cases

| Case | Behavior |
|------|----------|
| Multipart with HTML + text | Extract both |
| Multipart with only HTML | `body_text` is nil |
| Plain text only (no MIME) | `body_html` is nil |
| Inline images (cid:) | Stored as attachments with `inline: true` and `content_id` |
| Encoding issues | Use `mail` gem's `.decoded` which handles charset conversion |
| Oversized attachments | Reject at SMTP level if total message > `SMTP_MAX_MESSAGE_SIZE` (default: 3MB) |
| Missing From header | Default to `unknown@unknown` |

---

## Application Services

### ReceiveEmail (Primary Use Case)

```ruby
# app/application/services/receive_email.rb
module Inboxed
  module Services
    class ReceiveEmail
      def initialize(
        parser: ParseMime.new,
        inbox_repo: Infrastructure::Repositories::InboxRepository.new,
        email_repo: Infrastructure::Repositories::EmailRepository.new,
        event_store: EventStore::Store
      )
        @parser = parser
        @inbox_repo = inbox_repo
        @email_repo = email_repo
        @event_store = event_store
      end

      def call(project_id:, raw_source:, envelope_to:, source_type:, ttl_hours: nil)
        parsed = @parser.call(raw_source)

        envelope_to.each do |recipient|
          inbox = @inbox_repo.find_or_create_by_address(
            project_id: project_id,
            address: recipient
          )

          email_id = SecureRandom.uuid
          expires_at = Time.current + (ttl_hours || default_ttl(project_id)).hours

          inbox_aggregate = @event_store.load_aggregate(
            Aggregates::Inbox, inbox.id
          )

          inbox_aggregate.receive_email(
            id: email_id,
            from: parsed.from,
            to: parsed.to,
            subject: parsed.subject,
            body: ValueObjects::MessageBody.new(
              html: parsed.body_html,
              text: parsed.body_text
            ),
            attachments: parsed.attachments,
            raw_source: raw_source,
            source_type: source_type,
            expires_at: expires_at
          )

          @event_store.publish(
            stream: "Inbox-#{inbox.id}",
            events: inbox_aggregate.pending_events,
            metadata: { correlation_id: email_id }
          )

          @email_repo.save(email_id, inbox.id, parsed, raw_source, source_type, expires_at)
          save_attachments(email_id, parsed.attachments)

          inbox_aggregate.clear_pending_events
        end
      end

      private

      def default_ttl(project_id)
        project = ProjectRecord.find(project_id)
        project.default_ttl_hours ||
          ENV.fetch('EMAIL_TTL_HOURS', 168).to_i
      end

      def save_attachments(email_id, attachments)
        attachments.each do |att|
          AttachmentRecord.create!(
            email_id: email_id,
            filename: att[:filename],
            content_type: att[:content_type],
            size_bytes: att[:size_bytes],
            content: att[:content],
            content_id: att[:content_id],
            inline: att[:inline]
          )
        end
      end
    end
  end
end
```

### ReceiveEmailJob (Async Worker)

```ruby
# app/jobs/receive_email_job.rb
class ReceiveEmailJob < ApplicationJob
  queue_as :default

  def perform(project_id:, api_key_id:, envelope_from:, envelope_to:, raw_source:, source_type:)
    Inboxed::Services::ReceiveEmail.new.call(
      project_id: project_id,
      raw_source: raw_source,
      envelope_to: envelope_to,
      source_type: source_type
    )

    # Update API key last_used_at
    ApiKeyRecord.where(id: api_key_id).update_all(last_used_at: Time.current)
  end
end
```

### EmailCleanupJob

```ruby
# app/jobs/email_cleanup_job.rb
class EmailCleanupJob < ApplicationJob
  queue_as :maintenance

  def perform
    expired = EmailRecord.where("expires_at < ?", Time.current)
    count = expired.count

    # Delete attachments first (FK constraint)
    AttachmentRecord.where(email_id: expired.select(:id)).delete_all
    expired.delete_all

    # Update inbox counters
    InboxRecord.where("email_count > 0").find_each do |inbox|
      actual = EmailRecord.where(inbox_id: inbox.id).count
      inbox.update_column(:email_count, actual) if inbox.email_count != actual
    end

    Rails.logger.info("[EmailCleanup] Deleted #{count} expired emails")
  end
end
```

Scheduled via Solid Queue recurring config:

```yaml
# config/recurring.yml
cleanup:
  class: EmailCleanupJob
  schedule: every hour
```

### TTL Resolution Strategy

Email TTL (time-to-live) determines when emails expire and get purged. The value is resolved with the following precedence:

```
Project DB setting  →  ENV var  →  Global default (168h / 7 days)
```

| Source | Setting | Example |
|--------|---------|---------|
| **Global default** | Hardcoded | 168 hours (7 days) |
| **ENV var** | `EMAIL_TTL_HOURS` | `EMAIL_TTL_HOURS=48` for 2-day retention |
| **Project DB** | `projects.default_ttl_hours` | Per-project override via admin API |

Resolution in code:

```ruby
def resolve_ttl(project)
  project.default_ttl_hours ||
    ENV.fetch('EMAIL_TTL_HOURS', 168).to_i
end
```

This allows:
- **Self-hosters** to set a global retention via env var without touching the DB
- **Multi-tenant setups** to configure per-project retention via admin API
- **Sensible default** of 7 days — long enough to debug, short enough to not bloat storage

---

## Infrastructure

### Repositories

```ruby
# app/infrastructure/repositories/inbox_repository.rb
module Inboxed
  module Infrastructure
    module Repositories
      class InboxRepository
        def find_or_create_by_address(project_id:, address:)
          record = InboxRecord.find_or_create_by!(address: address) do |r|
            r.id = SecureRandom.uuid
            r.project_id = project_id
          end
          to_entity(record)
        end

        def find_by_id(id)
          record = InboxRecord.find_by(id: id)
          record ? to_entity(record) : nil
        end

        private

        def to_entity(record)
          Entities::Inbox.new(
            id: record.id,
            project_id: record.project_id,
            address: record.address,
            email_count: record.email_count,
            created_at: record.created_at
          )
        end
      end
    end
  end
end
```

```ruby
# app/infrastructure/repositories/email_repository.rb
module Inboxed
  module Infrastructure
    module Repositories
      class EmailRepository
        def save(id, inbox_id, parsed, raw_source, source_type, expires_at)
          EmailRecord.create!(
            id: id,
            inbox_id: inbox_id,
            from_address: parsed.from,
            to_addresses: parsed.to,
            cc_addresses: parsed.cc,
            subject: parsed.subject,
            body_html: parsed.body_html,
            body_text: parsed.body_text,
            raw_headers: parsed.headers,
            raw_source: raw_source,
            source_type: source_type,
            received_at: Time.current,
            expires_at: expires_at
          )

          InboxRecord.where(id: inbox_id).update_counters(email_count: 1)
        end
      end
    end
  end
end
```

### ActiveRecord Models (Persistence Only)

```ruby
# app/models/project_record.rb
class ProjectRecord < ApplicationRecord
  self.table_name = 'projects'
  has_many :api_keys, class_name: 'ApiKeyRecord', foreign_key: :project_id
  has_many :inboxes,  class_name: 'InboxRecord',  foreign_key: :project_id
end

# app/models/api_key_record.rb
class ApiKeyRecord < ApplicationRecord
  self.table_name = 'api_keys'
  belongs_to :project, class_name: 'ProjectRecord'
end

# app/models/inbox_record.rb
class InboxRecord < ApplicationRecord
  self.table_name = 'inboxes'
  belongs_to :project, class_name: 'ProjectRecord'
  has_many :emails, class_name: 'EmailRecord', foreign_key: :inbox_id
end

# app/models/email_record.rb
class EmailRecord < ApplicationRecord
  self.table_name = 'emails'
  belongs_to :inbox, class_name: 'InboxRecord'
  has_many :attachments, class_name: 'AttachmentRecord', foreign_key: :email_id
end

# app/models/attachment_record.rb
class AttachmentRecord < ApplicationRecord
  self.table_name = 'attachments'
  belongs_to :email, class_name: 'EmailRecord'
end
```

---

## Project Bootstrap: Seed Data & API Key Generation

A rake task to create the first project and API key for development:

```ruby
# lib/tasks/setup.rake
namespace :inboxed do
  desc "Create a default project and API key for development"
  task setup: :environment do
    project = ProjectRecord.find_or_create_by!(slug: 'default') do |p|
      p.name = 'Default Project'
      p.default_ttl_hours = nil  # uses ENV['EMAIL_TTL_HOURS'] or 168h default
    end

    token = SecureRandom.hex(32)  # 64-char token
    ApiKeyRecord.find_or_create_by!(project: project, label: 'dev') do |k|
      k.token_prefix = token[0..7]
      k.token_digest = BCrypt::Password.create(token)
    end

    puts "Project: #{project.name} (#{project.slug})"
    puts "API Key: #{token}"
    puts ""
    puts "SMTP config for your app:"
    puts "  SMTP_HOST=localhost"
    puts "  SMTP_PORT=2525"
    puts "  SMTP_USER=#{token}"
    puts "  SMTP_PASS=#{token}"
  end
end
```

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SMTP_PORTS` | `2525` | Comma-separated list of SMTP ports |
| `SMTP_HOST` | `0.0.0.0` | SMTP bind address |
| `SMTP_TLS_CERT` | — | Path to TLS certificate (PEM) |
| `SMTP_TLS_KEY` | — | Path to TLS private key (PEM) |
| `SMTP_MAX_MESSAGE_SIZE` | `3145728` | Max message size in bytes (3MB), configurable |
| `SMTP_MAX_CONNECTIONS` | `4` | Max concurrent SMTP sessions |
| `EMAIL_TTL_HOURS` | `168` | Global default email retention (7 days), overridden by project setting |

### Procfile

```
web: bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}
smtp: bundle exec rails runner "Inboxed::SmtpServer.start"
worker: bundle exec rails solid_queue:start
```

---

## Technical Decisions

### Decision: Inboxes created on-demand (catch-all)

- **Options:** (A) Pre-register inboxes, reject unknown addresses. (B) Accept any address, create inbox on first email.
- **Chosen:** B — catch-all with on-demand inbox creation
- **Why:** This is a dev tool. Developers don't want to pre-register every test address. The app sends to `user123@example.com` — Inboxed should just catch it. The API key on the SMTP connection already scopes to a project, which provides isolation.
- **Trade-offs:** Could accumulate many inboxes. Mitigated by `max_inbox_count` per project and cleanup job.

### Decision: Async email processing via Solid Queue

- **Options:** (A) Process synchronously in SMTP DATA handler. (B) Enqueue job, process async.
- **Chosen:** B — async via Solid Queue
- **Why:** SMTP sessions should be fast. MIME parsing, DB writes, and event publishing can take time. The SMTP server acknowledges receipt immediately and processes in the background. This also provides retry semantics for free.
- **Trade-offs:** Small delay between SMTP receipt and email appearing in the system. Acceptable for a dev tool — typically <1 second.

### Decision: API key authentication via bcrypt prefix lookup

- **Options:** (A) Hash full token, scan all keys. (B) Store prefix + digest, narrow lookup. (C) Store token in plain text.
- **Chosen:** B — prefix + bcrypt
- **Why:** Security by default. API keys are sensitive credentials. Storing only the bcrypt digest means a database leak doesn't expose keys. The 8-char prefix narrows the bcrypt comparison to typically 1 candidate, making auth fast.
- **Trade-offs:** Slightly more complex than plain text lookup. Worth it for security.

### Decision: UUID primary keys for all domain tables

- **Options:** (A) Sequential bigint IDs. (B) UUIDs.
- **Chosen:** B — UUIDs
- **Why:** Per ADR-001 recommendation. UUIDs can be generated client-side (in the SMTP handler before persistence), used as event stream names, and don't leak information about record count. Event stream names follow the `Aggregate-{uuid}` pattern.
- **Trade-offs:** Larger index size, no natural ordering. Mitigated by `created_at` / `received_at` indexes for time-based queries.

---

## Implementation Plan

### Step 1: Add gems

```ruby
gem "midi-smtp-server", "~> 3.3"
gem "mail", "~> 2.8"
```

### Step 2: Database migrations

Create migrations for `projects`, `api_keys`, `inboxes`, `emails`, `attachments`, and `snapshots` tables. Run `db:migrate`.

### Step 3: ActiveRecord models

Create `ProjectRecord`, `ApiKeyRecord`, `InboxRecord`, `EmailRecord`, `AttachmentRecord` in `app/models/`. Persistence-only — associations and scopes, no business methods.

### Step 4: Domain layer

1. Value objects: `EmailAddress`, `MessageBody`, `AttachmentInfo`
2. Entities: `Inbox`, `Email` (Dry::Struct)
3. Events: `ProjectCreated`, `ApiKeyIssued`, `InboxCreated`, `EmailReceived`, `EmailDeleted`, `InboxPurged`
4. Aggregates: `InboxAggregate`, `ProjectAggregate`

### Step 5: Repositories

Implement `InboxRepository` and `EmailRepository` in `app/infrastructure/repositories/`.

### Step 6: MIME parser

Implement `ParseMime` service in `app/application/services/`.

### Step 7: ReceiveEmail service

Implement the core orchestration service that ties MIME parsing, inbox lookup, event publishing, and persistence together.

### Step 8: SMTP server

Implement `Inboxed::SmtpServer` in `app/infrastructure/adapters/`. Wire up AUTH, MAIL FROM, RCPT TO, and DATA handlers.

### Step 9: Background jobs

1. `ReceiveEmailJob` — async email processing
2. `EmailCleanupJob` — TTL-based expiration
3. Configure Solid Queue recurring schedule

### Step 10: Rake setup task

Create `inboxed:setup` for bootstrapping dev environment with a default project and API key.

### Step 11: Event Store Phase 2 (Snapshots)

1. Create snapshots migration
2. Implement `SnapshotStore` in `infrastructure/event_store/`
3. Update `Store.load_aggregate` to check snapshots first
4. Snapshot every 50 events (configurable)

### Step 12: Tests

| What | Type | Location |
|------|------|----------|
| Value objects | Unit | `spec/domain/value_objects/` |
| Entities | Unit | `spec/domain/entities/` |
| Events | Unit | `spec/domain/events/` |
| Aggregates | Unit | `spec/domain/aggregates/` |
| ParseMime | Unit | `spec/application/services/parse_mime_spec.rb` |
| ReceiveEmail | Integration | `spec/application/services/receive_email_spec.rb` |
| Repositories | Integration | `spec/infrastructure/repositories/` |
| SMTP server | Integration | `spec/infrastructure/adapters/smtp_server_spec.rb` |
| Cleanup job | Integration | `spec/jobs/email_cleanup_job_spec.rb` |
| Snapshots | Integration | `spec/infrastructure/event_store/snapshot_store_spec.rb` |

### Step 13: Procfile & devcontainer update

Update Procfile for the SMTP process. Update `.devcontainer/devcontainer.json` to forward port 2525.

---

## Exit Criteria

- [ ] `midi-smtp-server` and `mail` gems installed
- [ ] All migrations run successfully (`projects`, `api_keys`, `inboxes`, `emails`, `attachments`, `snapshots`)
- [ ] Domain layer: value objects, entities, events, aggregates — all with unit tests, no Rails dependencies
- [ ] `ParseMime` correctly extracts HTML, text, and attachments from multipart MIME
- [ ] `ReceiveEmail` service persists email through event store and repositories
- [ ] SMTP server starts on port 2525, requires AUTH, accepts emails
- [ ] **End-to-end:** `swaks --to test@example.com --from app@test.com --server localhost:2525 --auth-user <api_key> --auth-password <api_key>` → email persisted in PostgreSQL
- [ ] `EmailCleanupJob` deletes expired emails
- [ ] `inboxed:setup` rake task creates project + API key and prints SMTP config
- [ ] Event Store Phase 2: snapshots working, `load_aggregate` uses snapshot when available
- [ ] All existing tests still pass
- [ ] CI green

---

## Open Questions

1. **Domain registration / accepted domains** — The ROADMAP mentions "reject mail for unregistered domains." In catch-all mode, should we still validate that the recipient domain is allowed per project config? Or is API key auth sufficient isolation? **Recommendation:** defer domain whitelisting to Phase 2. API key auth already scopes to a project, and in relay mode the recipient domain is irrelevant (the app thinks it's sending to a real address).

2. **Raw source storage** — Storing full MIME source per email could use significant disk space. Should we compress it (gzip) or make it optional? **Recommendation:** store as-is for now. Dev tools receive low volume. Add compression in Phase 7 if needed.

3. **Attachment size limit** — `SMTP_MAX_MESSAGE_SIZE` (default 3MB) covers the total MIME message. Individual attachment limits are unnecessary at this cap. If the limit is raised significantly in the future, revisit.
