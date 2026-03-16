# ADR-028: Cloud SMTP — Wildcard Subdomain Routing

**Status:** accepted
**Date:** 2026-03-16
**Deciders:** Project owner
**Panel consulted:** Email Infrastructure Engineer, Security Engineer, DevOps Engineer

## Context

In standalone mode, Inboxed's SMTP server receives all emails on a single configured domain. In cloud mode, multiple users need unique email addresses without conflicting. Each user's project needs its own namespace.

### Requirements

1. Each project gets a unique, auto-assigned email domain
2. No DNS configuration per user — it must work at registration time
3. Slugs should be unguessable (prevent enumeration / spam targeting)
4. Compatible with a single SMTP server process on a single VPS

### Options Considered

**A: Wildcard subdomain — `*@{slug}.inboxed.dev`**
- Pro: Standard MX-based routing — one wildcard MX record covers all projects
- Pro: Each project is a full subdomain — clean namespace isolation
- Pro: Works with any email client or SMTP sender
- Con: Requires wildcard DNS setup (one-time)
- Con: Long email addresses: `test@a7f3b2c1.inboxed.dev`

**B: Plus addressing — `{slug}+{inbox}@mail.inboxed.dev`**
- Pro: Single domain, no wildcard DNS
- Pro: Shorter addresses
- Con: Some SMTP senders strip or reject `+` in addresses
- Con: All emails go to one "account" — routing logic is custom
- Con: Doesn't scale to future features (webhook subdomains, etc.)

**C: Unique local part — `{slug}-{inbox}@mail.inboxed.dev`**
- Pro: Single domain, simple
- Con: Slug is in the local part — parsing is fragile (hyphens in inbox names vs slug separator)
- Con: Same "single domain" limitations as B

## Decision

**Option A** — wildcard subdomain routing with UUID-based slugs.

### Why Subdomains?

Subdomains are the natural isolation unit in email. They work with every SMTP implementation, every email client, and every third-party service. The slug is cleanly separated from the local part of the address, so `test@a7f3b2c1.inboxed.dev` unambiguously means "the `test` inbox in project `a7f3b2c1`."

### DNS Setup

One-time configuration (already documented in deploy guide):

```
MX    inboxed.dev          → mail.inboxed.dev  (priority 10)
MX    *.inboxed.dev        → mail.inboxed.dev  (priority 10)
A     mail.inboxed.dev     → <VPS IP>
```

The wildcard MX record (`*.inboxed.dev`) routes all subdomain email to the same SMTP server. No per-project DNS changes needed.

### SMTP Routing Logic

```ruby
# In SMTP server's mail handler
def route_recipient(recipient_address)
  # Parse: "test@a7f3b2c1.inboxed.dev"
  local_part, domain = recipient_address.split("@", 2)

  if cloud_mode? && domain.end_with?(".inboxed.dev")
    # Extract slug from subdomain: "a7f3b2c1"
    slug = domain.sub(".inboxed.dev", "")
    project = ProjectRecord.find_by(slug: slug)

    if project.nil?
      reject_recipient("550 5.1.1 Unknown project: #{slug}")
      return
    end

    inbox = find_or_create_inbox(project, local_part, domain)
    accept_and_store(inbox, recipient_address)
  else
    # Standalone: existing routing logic
    route_standalone(recipient_address)
  end
end
```

### Slug Generation

Project slugs in cloud mode are UUID-based (first 8 characters of a UUID v4):

```ruby
# On project creation in cloud mode
slug = SecureRandom.uuid.split("-").first  # e.g., "a7f3b2c1"
```

8 hex characters = 4 billion possible slugs. Unguessable at this entropy level, short enough for email addresses.

Standalone mode continues using user-provided slugs (e.g., "my-app", "staging").

### Per-User SMTP Rate Limiting

Cloud SMTP must prevent abuse:

```ruby
# In SMTP server, before accepting mail
def check_cloud_rate_limit(project)
  return unless cloud_mode?

  count = project.emails.where("received_at > ?", 1.hour.ago).count
  if count >= CLOUD_SMTP_RATE_LIMIT  # 10 emails/hour
    reject_recipient("450 4.7.1 Rate limit exceeded. Try again later.")
  end
end
```

### Email Verification via Dogfooding

User registration sends a verification email through Inboxed itself:

```
User registers → System sends verification email
  → Route: verification@system.inboxed.dev (internal system inbox)
  → Actually delivered via ActionMailer to user's real email
```

The system uses a dedicated `system.inboxed.dev` subdomain for operational emails (verification, password reset). These are sent via a configured outbound SMTP relay (not caught — actually delivered).

### Inbox Auto-Creation

In cloud mode, inboxes are auto-created on first email receipt (up to the project limit):

```ruby
def find_or_create_inbox(project, local_part, domain)
  address = "#{local_part}@#{domain}"
  inbox = InboxRecord.find_by(address: address)

  unless inbox
    CloudLimits.check!(:inbox, project: project)
    inbox = InboxRecord.create!(
      project: project,
      address: address,
      email_count: 0
    )
  end

  inbox
end
```

This means users don't need to pre-create inboxes — just point their app at `anything@{slug}.inboxed.dev` and it works.

## Consequences

### Easier

- **Zero user setup** — register, get a slug, use `anything@{slug}.inboxed.dev` immediately
- **Clean namespace** — subdomain = project, local part = inbox, no ambiguity
- **Standard DNS** — one wildcard MX record, compatible with all DNS providers
- **Scalable** — adding projects doesn't require DNS changes

### Harder

- **Long addresses** — `test@a7f3b2c1.inboxed.dev` is less pretty than `test@myapp.inboxed.dev`
- **Wildcard MX** — some DNS providers have limitations on wildcard MX records (rare)

### Mitigations

- UUID slugs are a security decision (unguessable) — the length trade-off is intentional
- Dashboard prominently displays the project's email domain for easy copy-paste
- Wildcard MX is standard and supported by all major DNS providers (Cloudflare, Route53, Hetzner DNS, etc.)
