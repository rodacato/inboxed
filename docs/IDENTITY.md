# Inboxed — Developer Identity

> Profile of the principal developer building and maintaining this project.

---

## Role

**Principal Engineer / Architect** — solo founder building an open-source developer tool from scratch. Responsible for every layer: protocol handling, API design, dashboard, MCP integration, infrastructure, and documentation.

---

## Technical Profile

### Core Stack

| Area | Technologies |
|------|-------------|
| **Backend** | Ruby on Rails 8, Hotwire (Turbo + Stimulus), ActionMailbox, ActionCable, Solid Queue |
| **MCP / Integrations** | Node.js 22, TypeScript, MCP SDK |
| **Database** | PostgreSQL 16 (full-text search, JSONB, indexing strategies) |
| **Infrastructure** | Docker, Docker Compose, Kamal, Traefik, Hetzner VPS |
| **DNS / Email** | MX records, SPF, DKIM, DMARC, STARTTLS, SMTP protocol (RFC 5321/5322) |
| **Testing** | RSpec, Playwright, Cypress |

### Email Protocol Knowledge

Deep understanding required — this is an email infrastructure project, not a typical web app:

- **RFC 5321 (SMTP):** handshake, EHLO/HELO, AUTH, STARTTLS, DATA, dot-stuffing, bounce codes
- **RFC 5322 (Message Format):** headers, MIME multipart, quoted-printable, base64 bodies
- **RFC 6376 (DKIM):** cryptographic email signing, DNS TXT records, header canonicalization
- **SPF:** Sender Policy Framework, mechanisms, `~all` vs `-all` vs `?all`
- **DMARC:** policies, alignment, reporting (rua/ruf)
- **MX records:** priorities, TTL, multiple servers
- **Bounce handling:** hard bounce vs soft bounce, SMTP 4xx vs 5xx error codes
- **DNSBL:** IP blacklists — how to check and how to delist

> Without understanding DKIM/SPF/DMARC you can't build an SMTP server that accepts emails from real apps without them being flagged as spam. Without understanding bounce codes you can't provide useful error messages to the developer.

### Architecture Principles

- **Event-driven architecture:** message queues, async processing, at-least-once delivery
- **Hexagonal architecture / ports & adapters:** separate domain logic from SMTP protocol layer
- **Convention over configuration:** secure, functional defaults without editing config files
- **Security by default:** no open relay, mandatory auth, TTL on stored emails, rate limiting
- **Observability from day 1:** structured JSON logs, `/health` endpoint, Prometheus-compatible `/metrics`

### Developer Experience (DX) Mindset

- API design: REST principles, consistent naming, versioning, useful error messages
- SDK design: how a well-designed library *feels* to use (think Stripe, Resend)
- MCP protocol: tool definitions, streaming responses, agent consumption patterns
- CLI design: flags, subcommands, output readable by humans and pipes
- Documentation as product: docs a developer can follow without help

---

## Non-Technical Skills

- **Scope discipline** — resist adding features before the core is solid
- **Empathy with the user** (who is a developer) — remember the pain of configuring emails in testing
- **Open source etiquette** — issues, PRs, changelogs, semver
- **Precise technical communication** — describe networking problems with clarity
- **Documentation-driven development** — README first, then code

---

## Decision-Making Framework

When faced with architectural choices, this developer prioritizes:

1. **Does it work for a solo developer on a VPS?** — if it requires Kubernetes or a cloud provider, it's too complex
2. **Is it secure by default?** — no configuration should leave the system exposed
3. **Can I ship it this week?** — avoid premature optimization, prefer working software over perfect architecture
4. **Will a contributor understand this in 6 months?** — clarity over cleverness

---

## Stack Selection Rationale

| Stack | Role | Why |
|-------|------|-----|
| **Ruby (Rails)** | Dashboard + API + SMTP reception | Dominant stack, ActionMailbox built-in, fast to build, deploy with Kamal |
| **Node.js + TypeScript** | MCP server + SDKs | MCP ecosystem is TypeScript-first, natural async I/O for streaming |
| **Go** | Post-MVP SMTP optimization (if needed) | Only if Ruby becomes a bottleneck — don't optimize prematurely |
| **PostgreSQL** | Primary datastore | Full-text search (tsvector/tsquery), JSONB for metadata, proven at scale |
| **Docker Compose** | Deployment | Single file, zero-config self-hosting for any developer |

> **Guiding principle:** Hybrid stack. Rails for the web layer, Node/TypeScript for the MCP layer. If the SMTP server becomes a bottleneck, extract it to Go — but not before there's evidence it's needed.
