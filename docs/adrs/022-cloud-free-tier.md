# ADR-022: Inboxed Cloud — Free Tier as Self-Hosted Funnel

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner
**Panel consulted:** Product Manager, DevOps Engineer, Security Engineer, Full-Stack Engineer, UX Designer, Developer Advocate

## Context

Inboxed is a self-hosted tool. Self-hosted tools have an adoption problem: developers must install, configure, and run the tool before they know if it solves their problem. This friction kills adoption.

The industry pattern (Plausible, Umami, Gitea, n8n) is to offer a free hosted tier that lets developers try the product instantly, then nudge them toward self-hosting when they outgrow the limits.

### Options Considered

**A: No hosted version — self-hosted only**
- Pro: Zero hosting costs, zero multi-tenant complexity
- Con: High adoption friction — developers won't `docker compose up` for something they haven't tried
- Con: No live demo to share or link to

**B: Free cloud tier as funnel to self-hosted**
- Pro: 30-second time-to-value — register, get an inbox, send a test email
- Pro: Same codebase with a mode flag, not a separate product
- Pro: Budget-friendly (~€7-10/mo for a single VPS)
- Con: Multi-tenant adds security surface area
- Con: SMTP in cloud requires wildcard DNS and abuse prevention

**C: Full SaaS with paid plans**
- Pro: Revenue potential
- Con: Massive scope increase (billing, plans, support, SLAs, compliance)
- Con: Competes with Mailtrap/Mailpit on their terms instead of differentiating
- Con: Contradicts the self-hosted philosophy

## Decision

**Option B** — free cloud tier with intentional limits that make self-hosting the natural next step.

### Core Principle

Cloud is a marketing cost, not a revenue stream. Success is measured by `docker pull` conversions, not cloud retention.

### Mode Flag

The same Rails application runs in two modes:

```
INBOXED_MODE=standalone  # Self-hosted (default) — single tenant, admin token, all features
INBOXED_MODE=cloud       # Hosted — multi-tenant, user registration, limited features
```

No separate codebase, no separate deploy pipeline. Conditional behavior is minimal and contained in a `CloudMode` concern/module.

### Free Tier Limits

| Resource | Limit | Rationale |
|---|---|---|
| Projects per user | 1 | Enough to evaluate, not enough for a team |
| Inboxes per project | 5 | Covers a basic signup/reset/invite flow |
| Emails retained | 50 | Fills up in one test session |
| Webhook endpoints | 2 | Demo, not production |
| Requests per endpoint | 20 | Same principle |
| Email/webhook TTL | 1 hour | Non-negotiable — keeps storage near zero for idle accounts |
| API rate limit | 60 req/min | Manual testing yes, CI/CD no |
| SMTP rate limit | 10 emails/hour | Prevents relay abuse |
| Max email body | 100KB | Prevents storage abuse |
| Max webhook body | 256KB | Same |

### Feature Gates (Cloud Disabled)

| Feature | Why disabled |
|---|---|
| **MCP server** | Key differentiator — only available in self-hosted. Strongest conversion driver |
| **HTML email preview** | Cross-tenant XSS risk. Cloud shows text + headers only |
| **Custom TTL** | Cloud TTL is 1 hour, non-configurable. Self-hosted can set any value |
| **Webhook relay/forward** | Too much abuse potential in a shared environment |

### Data Model

Two additional tables beyond the self-hosted schema:

```
users
  id: bigint PK
  email: string (unique, indexed)
  password_digest: string
  verified_at: datetime (null until email confirmed)
  created_at: datetime

users_projects
  user_id: bigint FK
  project_id: bigint FK
  role: string (default: "owner")
  unique index on [user_id, project_id]
```

In standalone mode, these tables exist but are unused. No conditional migrations.

### Multi-Tenant SMTP

Wildcard subdomain routing via a single MX record:

```
MX  inboxed.dev → mail.inboxed.dev
A   mail.inboxed.dev → <VPS IP>
```

All emails to `*@{slug}.inboxed.dev` arrive at the same SMTP server. The server extracts the subdomain from the recipient address and routes to the correct project. Slugs are UUIDs to prevent enumeration.

### Infrastructure

| Component | Choice | Monthly cost |
|---|---|---|
| VPS | Hetzner CAX21 (4 vCPU ARM, 8GB) | ~€6 |
| Backups | pg_dump daily → Hetzner Object Storage | ~€1 |
| DNS | Wildcard *.inboxed.dev | Included |
| **Total** | | **~€7-10** |

No Redis (Solid Cable uses PostgreSQL), no CDN, no separate workers (Solid Queue in-process at this scale).

### Security (Non-Negotiable)

| Vector | Mitigation |
|---|---|
| Cross-tenant data leak | Every query scoped by `project_id`. Integration tests verify isolation |
| SMTP open relay abuse | Registration requires email verification. Per-account SMTP rate limit |
| Storage abuse | 1h TTL, body size caps, cleanup cron every 5 minutes |
| HTML email XSS | No HTML rendering in cloud mode — text and headers only |
| Account enumeration | Slugs are UUIDs, registration doesn't reveal existing emails |
| SMTP DDoS | fail2ban on SMTP port + midi-smtp-server connection rate limit |
| Spam registrations | Email verification required before any inbox is functional |

## Consequences

### Easier

- **Instant adoption** — developers try Inboxed in 30 seconds without installing anything
- **Live demo** — every cloud account is a working demo you can link to
- **Same codebase** — no fork, no separate maintenance burden
- **Budget-friendly** — single VPS, cost of a coffee per month

### Harder

- **Multi-tenant security** — every feature must be audited for tenant isolation
- **Abuse prevention** — public SMTP endpoint will attract abuse; needs ongoing monitoring
- **Two modes to test** — CI must verify both standalone and cloud behavior

### Mitigations

- Cloud mode is strictly additive — standalone is the default and has zero multi-tenant code paths
- Aggressive TTL + cleanup keeps storage bounded regardless of user count
- Feature gates (no MCP, no HTML) eliminate the highest-risk cross-tenant vectors
- Idle accounts cost effectively nothing (1 row in `users`, expired data auto-cleaned)
