# Inboxed — Agent Instructions

> How AI agents should use this repository's documentation to provide the best assistance.

---

## What is Inboxed?

Inboxed is a **self-hosted SMTP server built for developers and QA automation**. It catches test emails sent by your application and makes them accessible via REST API, MCP server, and a web dashboard. No emails ever reach a real inbox.

**Core value proposition:** Point your app's SMTP config at Inboxed, send test emails, and inspect them programmatically — including from AI agents via MCP.

**Key differentiator:** Native MCP server integration. No competitor offers this. AI agents can extract OTPs, verification links, and email content without leaving their execution context.

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Web + API | Ruby on Rails 8, Hotwire |
| SMTP server | midi-smtp-server gem |
| MCP server | Node.js 22, TypeScript, MCP SDK |
| Database | PostgreSQL 16 |
| Background jobs | Solid Queue |
| Real-time | Turbo Streams + ActionCable |
| Deploy | Docker + Kamal |

### Repository Structure

```
inboxed/
├── apps/
│   ├── api/           # Rails 8 API-only
│   ├── dashboard/     # Svelte 5 SPA + Tailwind 4
│   └── mcp/           # Node.js MCP server (TypeScript)
├── docs/
│   ├── specs/         # Implementation specs
│   └── adrs/          # Architecture Decision Records
├── config/
│   └── deploy.yml     # Kamal deploy configuration
├── .devcontainer/     # Dev environment
├── docker-compose.yml
└── .env.example
```

---

## How to Use the Documentation

### IDENTITY.md — Who is building this

Read [IDENTITY.md](docs/IDENTITY.md) to understand the developer's technical profile, stack expertise, and decision-making framework. Use this to:

- **Calibrate technical depth** — this is a senior developer with deep Ruby/Rails and Node/TypeScript experience, plus email protocol knowledge. Don't over-explain basics.
- **Match the stack** — prefer Rails conventions, Hotwire patterns, and PostgreSQL-native solutions. Don't suggest MongoDB, Next.js, or technologies outside the defined stack unless asked.
- **Respect the principles** — convention over configuration, security by default, single `docker-compose.yml` deployment. Solutions that violate these principles need strong justification.
- **Scope discipline** — this is a dev tool, not a production email server. Features that blur that line are out of scope.

### EXPERTS.md — Panel of domain specialists

Read [EXPERTS.md](docs/EXPERTS.md) when asked to adopt an expert persona or when a decision requires domain-specific knowledge. Use this to:

- **Respond as a specific expert** when the user says "act as the [role]" or "what would the [role] think about this?"
- **Convene a panel** when a decision cuts across multiple domains (e.g., SMTP architecture touches Email Infrastructure + Security + DevOps)
- **Stay in character** — each expert has a defined specialty, knowledge base, and communication style. Maintain that perspective consistently.
- **Use the panel composition table** at the bottom of EXPERTS.md to quickly identify which experts are relevant for a given topic.

### ROADMAP.md — What we're building and in what order

Read [ROADMAP.md](docs/ROADMAP.md) to understand the current phase, priorities, and what comes next. Use this to:

- **Know where we are** — check the current phase and completed tasks before suggesting work.
- **Stay focused on the current phase** — don't jump ahead unless the user explicitly asks to discuss future phases.
- **Understand exit criteria** — each phase has clear "done" conditions. Work toward those.
- **Respect priorities** — Phase 4 (MCP) is the key differentiator. Decisions that compromise MCP quality for other features should be flagged.

### Other Documentation

| Document | When to read |
|----------|-------------|
| [specs/](docs/specs/) | Before implementing anything — read the approved spec for the current work |
| [adrs/](docs/adrs/) | When making or reviewing architectural decisions |
| [BRANDING.md](docs/BRANDING.md) | When working on UI, dashboard, or any visual component |
| [CONTRIBUTING.md](CONTRIBUTING.md) | When discussing code style, PR process, or community guidelines |
| [SECURITY.md](SECURITY.md) | When reviewing security-sensitive code or architecture |
| [CHANGELOG.md](CHANGELOG.md) | When documenting changes for a release |
| [VISION.md](docs/VISION.md) | When discussing scope, new modules, or long-term product direction |

---

## Agent Behavior Guidelines

### When writing code for this project:

1. **Follow Rails conventions** — standard Ruby style, `bundle exec standardrb` compliance
2. **TypeScript for MCP and Dashboard** — strict types, ESLint compliance
3. **Tailwind utility classes only** — no custom CSS without justification
4. **Conventional commits** — `feat:`, `fix:`, `docs:`, `chore:`
5. **Test everything** — RSpec for Ruby, Vitest for TypeScript
6. **No sensitive data** — never hardcode API keys, IPs, domains, or personal information in code or docs

### Architecture Layer Rules (see [spec 001](docs/specs/001-architecture.md) and [ADRs](docs/adrs/))

The Rails API uses a **rich DDD architecture** with strict layer separation. These rules are non-negotiable:

#### Where code goes

| I'm writing... | Put it in... |
|----------------|-------------|
| Business rule or invariant | `app/domain/entities/` or `app/domain/aggregates/` |
| Immutable data holder (no ID) | `app/domain/value_objects/` |
| A fact that happened | `app/domain/events/` |
| Use case orchestration | `app/application/services/` |
| Database access | `app/infrastructure/repositories/` |
| External API call | `app/infrastructure/adapters/` |
| ActiveRecord model | `app/models/` — **persistence only**, no business methods |
| Query-optimized view | `app/read_models/` |
| HTTP endpoint | `app/controllers/` — thin, delegates to service |

#### Layer boundaries

- **`domain/`** has **zero** Rails or ActiveRecord dependencies. Only `dry-types` and `dry-struct`.
- **Entities and value objects** are immutable (`Dry::Struct`).
- **Application services** orchestrate only — no `if` statements checking business rules.
- **Repositories** translate between domain entities and AR models. The domain never sees `ActiveRecord::Base`.
- **AR models** have no business methods. Only scopes, associations, DB validations.
- **Controllers** are thin — parse params, call service, serialize response.

#### Svelte Dashboard

- **Feature-based** — each feature in `src/features/<name>/` with `.svelte`, `.service.ts`, `.store.ts`, `.types.ts`
- **Components are dumb** — props in, events out, no direct API calls
- **Services** handle all API communication
- **Stores** use Svelte 5 runes (`$state`, `$derived`)
- Features import from `lib/`, never from other features

#### MCP Server

- **Tools + Ports** — each tool in `src/tools/<name>.ts`, external calls in `src/ports/`
- **Tools are pure functions** — receive input + port, return output
- **Zero state** — each invocation is independent

### When making architectural decisions:

1. Read IDENTITY.md for the decision-making framework
2. Read [ADRs](docs/adrs/) for existing architectural decisions
3. Consult the relevant experts from EXPERTS.md
4. Check ROADMAP.md to understand how the decision fits in the current phase
5. Prefer simplicity — the right amount of complexity is the minimum needed

### When unsure about scope:

Ask: "Is this a testing/dev tool feature, or is this crossing into production email server territory?" If it's the latter, it's likely out of scope.
