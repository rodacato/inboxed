# 007 — Deploy & Self-Hosting

> From `git clone` to receiving test emails in under 10 minutes.

**Phase:** Phase 6 — Deploy & Self-Hosting
**Status:** implemented
**Release:** —
**Depends on:** [000 — Foundation](000-foundation.md), all prior specs (functional Inboxed stack)
**ADRs:** [ADR-017 Setup Script](../adrs/017-setup-script-secure-defaults.md), [ADR-018 Landing Page](../adrs/018-static-landing-page.md), [ADR-019 Docker Compose Primary](../adrs/019-docker-compose-primary-deploy.md)

---

## 1. Objective

Make Inboxed **trivially self-hostable**. A developer should be able to go from discovering the project to catching their first test email in under 10 minutes, with zero prior knowledge of the codebase.

This spec covers three pillars:

1. **Deploy infrastructure** — production-ready Docker setup, CI/CD, multi-arch images
2. **Documentation** — quickstart, self-hosting guide, DNS guide, configuration reference
3. **Landing page** — public-facing page for the open-source launch

## 2. Current State

| Component | Status | Notes |
|-----------|--------|-------|
| `docker-compose.yml` | Complete | All services: api, dashboard, mcp, db, redis |
| API Dockerfile | Complete | Multi-stage, jemalloc, non-root user |
| Dashboard Dockerfile | Complete | SPA build → Caddy static serving |
| MCP Dockerfile | Complete | Node.js TypeScript build |
| `config/deploy.yml` | Template | Kamal config with placeholders |
| `.env.example` | Complete | All vars documented |
| Health checks | Complete | `/up`, `/admin/status`, `/api/v1/status` |
| GitHub Actions CI | Partial | Tests + lint only, no image build/push |
| Structured logging | Not started | — |
| `bin/setup` | Not started | — |
| DNS documentation | Not started | — |
| Self-hosting guide | Not started | — |
| Landing page | Not started | BRANDING.md has full design spec |

## 3. What This Spec Delivers

### 3.1 Setup Script (`bin/setup`)

Interactive script that configures Inboxed for first run. See ADR-017.

### 3.2 Structured JSON Logging

Production logs as structured JSON to stdout for log aggregation.

### 3.3 CI/CD Docker Pipeline

GitHub Actions workflow that builds and pushes multi-arch Docker images to ghcr.io.

### 3.4 Documentation Suite

| Document | Purpose |
|----------|---------|
| `README.md` (rewrite) | Elevator pitch + 3-command quickstart |
| `docs/guides/self-hosting.md` | Complete VPS deployment walkthrough |
| `docs/guides/dns-setup.md` | A, MX, SPF record configuration |
| `docs/guides/configuration.md` | Every environment variable explained |
| `docs/guides/upgrading.md` | How to update between versions |
| `docs/guides/kamal-deploy.md` | Optional advanced deployment with Kamal |

### 3.5 Landing Page

Static HTML + Tailwind page in `site/`, deployed to GitHub Pages. See ADR-018.

---

## 4. Setup Script Specification

### 4.1 `bin/setup`

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Banner
echo "[@] Inboxed Setup"

# 2. Prerequisites check
check_command "docker" "Docker is required. Install: https://docs.docker.com/get-docker/"
check_command "docker compose" "Docker Compose v2 is required."

# 3. Interactive configuration
read -p "Domain [localhost]: " INBOXED_DOMAIN
INBOXED_DOMAIN="${INBOXED_DOMAIN:-localhost}"

read -p "Dashboard port [80]: " DASHBOARD_PORT
DASHBOARD_PORT="${DASHBOARD_PORT:-80}"

read -p "SMTP port [587]: " SMTP_PORT
SMTP_PORT="${SMTP_PORT:-587}"

# 4. Generate secrets (never prompt for passwords)
SECRET_KEY_BASE=$(openssl rand -hex 64)
INBOXED_ADMIN_TOKEN=$(openssl rand -hex 32)
POSTGRES_PASSWORD=$(openssl rand -hex 32)

# 5. Write .env (from .env.example template)
# 6. Validate (check port availability, warn if conflicts)
# 7. Print next steps
```

### 4.2 `bin/check`

Health verification script for post-setup:

```bash
#!/usr/bin/env bash
# Verify all services are running and healthy

echo "[@] Inboxed Health Check"

check_service "API"       "http://localhost:3000/up"
check_service "Dashboard" "http://localhost:${DASHBOARD_PORT:-80}"
check_service "Database"  "docker compose exec db pg_isready"
check_service "Redis"     "docker compose exec redis redis-cli ping"
check_service "SMTP"      "nc -z localhost ${SMTP_PORT:-587}"
```

### 4.3 Security Constraints

- Secrets generated with `openssl rand -hex` (cryptographically secure)
- `.env` created with `chmod 600` (owner-only read/write)
- SMTP ports bind to `127.0.0.1` by default in docker-compose
- Script warns if running as root

---

## 5. Structured JSON Logging

### 5.1 Rails API

Configure Rails to output structured JSON logs in production:

```ruby
# config/environments/production.rb
config.log_formatter = ::Logger::Formatter.new
config.logger = ActiveSupport::TaggedLogging.logger(
  ActiveSupport::Logger.new($stdout)
)

# Use lograge for structured request logging
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new
config.lograge.custom_payload do |controller|
  {
    request_id: controller.request.request_id,
    ip: controller.request.remote_ip
  }
end
```

**Log format:**
```json
{
  "method": "GET",
  "path": "/api/v1/inboxes",
  "format": "json",
  "controller": "Api::V1::InboxesController",
  "action": "index",
  "status": 200,
  "duration": 12.34,
  "request_id": "abc-123",
  "ip": "10.0.0.1",
  "timestamp": "2026-03-15T20:00:00Z"
}
```

### 5.2 SMTP Server

Add structured logging to the SMTP server process:

```json
{
  "service": "smtp",
  "event": "email_received",
  "from": "app@example.com",
  "to": "test@mail.inboxed.dev",
  "subject": "Verify your account",
  "size_bytes": 4521,
  "duration_ms": 45,
  "timestamp": "2026-03-15T20:00:01Z"
}
```

### 5.3 Gem Dependencies

- `lograge` — structured request logging (already standard in Rails production)
- No other dependencies needed

---

## 6. CI/CD Docker Pipeline

### 6.1 New Workflow: `.github/workflows/docker.yml`

Triggers on:
- Push to `main` (build + push `latest` tag)
- Git tags matching `v*` (build + push version tag)

```yaml
name: Docker Build & Push

on:
  push:
    branches: [main]
    tags: ["v*"]

jobs:
  build-api:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          context: apps/api
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ghcr.io/${{ github.repository }}/api:latest
            ghcr.io/${{ github.repository }}/api:${{ github.ref_name }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  build-dashboard:
    # Same pattern for apps/dashboard

  build-mcp:
    # Same pattern for apps/mcp
```

### 6.2 Image Tags

| Trigger | Tags |
|---------|------|
| Push to `main` | `latest` |
| Tag `v1.0.0` | `v1.0.0`, `latest` |

### 6.3 Multi-arch

All images built for `linux/amd64` and `linux/arm64` using Docker Buildx + QEMU. This covers:
- x86 VPS (Hetzner, DigitalOcean, Linode)
- ARM VPS (Oracle Cloud free tier, AWS Graviton)
- Local development on Apple Silicon

---

## 7. Documentation Suite

### 7.1 README.md Rewrite

The README is the most important document in the project. Structure:

```markdown
# [@] Inboxed

> Your emails go nowhere. You see everything.

**Inboxed** is a self-hosted SMTP server for developers and QA.
Catch test emails, inspect them via API or dashboard,
and extract OTPs from AI agents via MCP.

## Quickstart

    git clone https://github.com/user/inboxed && cd inboxed
    bin/setup
    docker compose up -d

Open http://localhost — your dashboard is ready.
Send a test email: `swaks --to test@localhost --server localhost:587`

## Features

- **SMTP server** — point your app's SMTP config, catch all emails
- **REST API** — list, search, wait for emails programmatically
- **Dashboard** — real-time inbox viewer with search and OTP detection
- **MCP server** — AI agents extract OTPs and links without leaving context
- **Client libraries** — TypeScript and Ruby clients for test automation

## Documentation

- [Self-hosting guide](docs/guides/self-hosting.md)
- [DNS setup](docs/guides/dns-setup.md)
- [Configuration reference](docs/guides/configuration.md)
- [REST API](docs/specs/003-rest-api.md)
- [MCP tools](docs/specs/005-mcp-server.md)

## License

MIT
```

**Key principles:**
- Tagline from BRANDING.md
- 3-command quickstart (clone, setup, up)
- Features as one-liners, not paragraphs
- Links to docs, not inline documentation

### 7.2 `docs/guides/self-hosting.md`

Complete walkthrough from blank VPS to running Inboxed:

```
## Prerequisites
- VPS with 1GB RAM, 10GB disk (any Linux distro)
- Docker and Docker Compose v2 installed
- A domain name (optional for localhost testing)

## Step 1: Clone and Setup
## Step 2: Configure Domain (optional)
## Step 3: Start Services
## Step 4: Verify Installation
## Step 5: Send Your First Test Email
## Step 6: Configure Your App's SMTP
## Step 7: DNS Setup (for receiving email on a real domain)

## Firewall Rules
## Monitoring & Logs
## Backup & Restore
## Troubleshooting
```

**Key principle:** The guide works **without DNS** for localhost testing. DNS is Step 7, not Step 1.

### 7.3 `docs/guides/dns-setup.md`

For users who want to receive email on a real domain:

```
## Overview
Inboxed needs DNS records to receive email on your domain.

## Required Records

| Type | Name | Value | Purpose |
|------|------|-------|---------|
| A    | mail.example.com | <VPS_IP> | Points to your server |
| MX   | example.com | mail.example.com (priority 10) | Routes email to your server |
| TXT  | example.com | v=spf1 a:mail.example.com ~all | SPF authorization |

## Step-by-Step (by provider)
### Cloudflare
### Namecheap
### Route 53

## TLS Certificates
## Verification
## Troubleshooting

## Security Warning
> ⚠ Incorrect MX records can route real email to your test server.
> Only configure MX records for domains dedicated to testing.
```

### 7.4 `docs/guides/configuration.md`

Every environment variable, grouped by category:

```
## Required
| Variable | Description | Example |
|----------|-------------|---------|
| INBOXED_DOMAIN | Your Inboxed domain | mail.example.com |
| INBOXED_ADMIN_TOKEN | Dashboard login token | (auto-generated) |
| SECRET_KEY_BASE | Rails secret | (auto-generated) |
| POSTGRES_PASSWORD | Database password | (auto-generated) |

## Ports
| Variable | Default | Description |
|----------|---------|-------------|
| INBOXED_WEB_PORT | 80 | Dashboard HTTP port |
| INBOXED_SMTP_PORT | 587 | SMTP STARTTLS port |
| ...

## Limits
| Variable | Default | Description |
|----------|---------|-------------|
| INBOXED_DEFAULT_TTL_HOURS | 168 (7d) | Email retention |
| INBOXED_MAX_EMAILS_PER_PROJECT | 10000 | Storage cap |
| ...

## Advanced
| Variable | Default | Description |
|----------|---------|-------------|
| RAILS_LOG_LEVEL | info | Log verbosity |
| ...
```

### 7.5 `docs/guides/upgrading.md`

```
## Upgrading Inboxed

### Standard Upgrade (Docker Compose)

    cd inboxed
    git pull
    docker compose pull        # if using pre-built images
    docker compose up -d --build  # if building locally
    docker compose exec api rails db:migrate

### Breaking Changes
Check CHANGELOG.md before upgrading between major versions.

### Rollback
    git checkout v1.0.0
    docker compose up -d --build
```

### 7.6 `docs/guides/kamal-deploy.md`

Optional guide for advanced users:

```
## Deploy with Kamal

Kamal provides zero-downtime deploys and rolling restarts.
Use this if you need production-grade deployment for a team.

### Prerequisites
- Ruby installed locally (for Kamal gem)
- SSH access to your VPS
- Container registry credentials (ghcr.io)

### Setup
### First Deploy
### Subsequent Deploys
### Rollback
```

---

## 8. Landing Page

### 8.1 Technical Stack

| Layer | Choice |
|-------|--------|
| HTML | Single `index.html` |
| CSS | Tailwind CSS (CDN or CLI build) |
| Fonts | Space Grotesk, JetBrains Mono, Inter (Google Fonts) |
| JavaScript | None (CSS-only animations) |
| Hosting | GitHub Pages |
| Build | Tailwind CLI standalone (no Node required) |

### 8.2 Page Sections

**Hero:**
```
[@] inboxed

Your emails go nowhere. You see everything.

Self-hosted SMTP server for developers and QA.
Catch test emails. Inspect via API. Extract OTPs with AI agents.

[Get Started →]  [GitHub →]
```

**Problem:**
```
Every dev tool sends test emails somewhere.
Yours sends them here.

No Mailtrap account. No shared inbox. No leaked credentials.
Self-hosted. Open source. Yours.
```

**Features (3 columns):**
```
[@] Catch                  [~] Inspect                [⚡] Assert
SMTP server that           Dashboard, REST API,       MCP server for AI
catches all test           real-time updates,         agents, client libs
emails. Point your         full-text search.          for Playwright, RSpec.
app's SMTP config          See everything.            Zero sleeps.
and go.
```

**Quickstart (terminal block):**
```
$ git clone https://github.com/user/inboxed && cd inboxed
$ bin/setup
  ✓ Secrets generated
  ✓ .env written
$ docker compose up -d
  ✓ API ready on :3000
  ✓ Dashboard ready on :80
  ✓ SMTP ready on :587
```

**MCP Highlight:**
```
The first email dev server with native AI agent integration.

Agent: "Sign up with test@mail.inboxed.dev and verify the account"

→ extract_code("test@mail.inboxed.dev")
← { "code": "847291" }

No browser. No manual copy-paste. No sleeps.
```

**Footer:**
```
[@] inboxed · MIT License · GitHub · notdefined.dev
```

### 8.3 File Structure

```
site/
├── index.html           # Single page
├── styles/
│   └── main.css         # Tailwind output (built)
├── assets/
│   ├── logo.svg         # [@] logo
│   └── og-image.png     # Social media preview
├── tailwind.config.js   # Tailwind config with BRANDING.md colors
└── build.sh             # Tailwind CLI build script
```

### 8.4 GitHub Pages Deployment

Add to CI:

```yaml
# .github/workflows/pages.yml
name: Deploy Landing Page

on:
  push:
    branches: [main]
    paths: [site/**]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - name: Build CSS
        run: cd site && ./build.sh
      - uses: actions/upload-pages-artifact@v3
        with:
          path: site/
      - uses: actions/deploy-pages@v4
```

### 8.5 SEO & Social

- `<title>Inboxed — Self-hosted SMTP for developers</title>`
- `<meta name="description" content="Catch test emails, inspect via API, extract OTPs with AI agents. Self-hosted, open source.">`
- Open Graph image: dark terminal aesthetic with `[@] inboxed` logo
- Canonical URL: `https://inboxed.notdefined.dev`

---

## 9. Technical Decisions

### 9.1 Decision: Docker Compose as Primary Deploy Path

See [ADR-019](../adrs/019-docker-compose-primary-deploy.md). Docker Compose is the recommended method. Kamal documented as optional advanced path.

### 9.2 Decision: Interactive Setup Script

See [ADR-017](../adrs/017-setup-script-secure-defaults.md). `bin/setup` generates secrets and `.env` interactively. Secure by default.

### 9.3 Decision: Static Landing Page

See [ADR-018](../adrs/018-static-landing-page.md). Single HTML page with Tailwind, deployed to GitHub Pages. No JavaScript, no framework.

### 9.4 Decision: Lograge for Structured Logging

- **Options considered:** (A) Custom JSON formatter, (B) Lograge, (C) Semantic Logger
- **Chosen:** B — Lograge
- **Why:** De facto standard for Rails JSON logging. Single line per request, configurable payload, zero learning curve.
- **Trade-offs:** Less granular than Semantic Logger. Acceptable for a dev tool.

### 9.5 Decision: Localhost-First Documentation

- **Options considered:** (A) DNS setup first, then localhost, (B) Localhost first, DNS optional later
- **Chosen:** B — localhost works out of the box, DNS is an optional enhancement
- **Why:** DNS setup is the #1 blocker for first-run experience. A user should be able to test Inboxed on their laptop before committing to DNS changes. The quickstart works with `localhost`, no domain required.

---

## 10. Implementation Plan

### Step 1: Setup Scripts

Create `bin/setup` and `bin/check`:
- Prerequisites validation (Docker, Docker Compose)
- Interactive domain/port configuration
- Secret generation with `openssl rand -hex`
- `.env` file creation from template
- Post-setup health check

### Step 2: Structured Logging

Add `lograge` gem and configure:
- JSON log format for Rails requests
- Structured logging for SMTP server events
- Log level configurable via `RAILS_LOG_LEVEL` env var
- All logs to stdout (Docker-friendly)

### Step 3: Docker Compose Hardening

Review and finalize `docker-compose.yml`:
- SMTP ports bound to `127.0.0.1` by default
- Health checks for all services
- Restart policies (`unless-stopped`)
- Resource limits (memory) as comments/examples
- Volume mount paths documented

### Step 4: CI/CD Docker Workflow

Create `.github/workflows/docker.yml`:
- Multi-arch builds (amd64 + arm64) with Buildx + QEMU
- Push to ghcr.io on main push and version tags
- Cache layers with GitHub Actions cache
- Separate jobs per service (api, dashboard, mcp)

### Step 5: README Rewrite

Rewrite `README.md` following section 7.1:
- Tagline and elevator pitch
- 3-command quickstart
- Feature bullets
- Links to documentation

### Step 6: Documentation Guides

Write the full documentation suite:
1. `docs/guides/self-hosting.md` — VPS walkthrough (localhost → DNS)
2. `docs/guides/dns-setup.md` — A, MX, SPF records with provider examples
3. `docs/guides/configuration.md` — complete env var reference
4. `docs/guides/upgrading.md` — update and rollback procedures
5. `docs/guides/kamal-deploy.md` — optional advanced deployment

### Step 7: Landing Page

Build `site/`:
1. `index.html` with all sections from BRANDING.md
2. Tailwind CSS with custom color palette (phosphor green, near-black)
3. CSS-only animated terminal demo
4. Open Graph meta tags + social image
5. `build.sh` for Tailwind CLI standalone build

### Step 8: GitHub Pages Workflow

Create `.github/workflows/pages.yml`:
- Trigger on changes to `site/`
- Build Tailwind CSS
- Deploy to GitHub Pages

### Step 9: End-to-End Verification

Run the full "new user" flow on a clean machine:
1. `git clone` the repo
2. `bin/setup` (accept defaults)
3. `docker compose up -d`
4. Open dashboard, verify it loads
5. Send email via `swaks --to test@localhost --server localhost:587`
6. Verify email appears in dashboard
7. Verify email accessible via API
8. Time the entire process (must be <10 minutes)

---

## 11. File Structure (New/Modified Files)

```
inboxed/
├── bin/
│   ├── setup                          # Interactive setup script
│   └── check                          # Health verification script
├── README.md                          # Rewritten with quickstart
├── docker-compose.yml                 # Hardened (ports, healthchecks, restarts)
├── .github/workflows/
│   ├── ci.yml                         # Existing (no changes)
│   ├── docker.yml                     # NEW: multi-arch build + push
│   └── pages.yml                      # NEW: landing page deploy
├── docs/guides/
│   ├── self-hosting.md                # VPS deployment walkthrough
│   ├── dns-setup.md                   # A, MX, SPF records
│   ├── configuration.md              # Env var reference
│   ├── upgrading.md                   # Update procedures
│   └── kamal-deploy.md               # Optional Kamal guide
└── site/
    ├── index.html                     # Landing page
    ├── styles/
    │   └── main.css                   # Tailwind output
    ├── assets/
    │   ├── logo.svg
    │   └── og-image.png
    ├── tailwind.config.js
    └── build.sh                       # Tailwind CLI build
```

---

## 12. Exit Criteria

### Setup & Deploy

- [ ] **EC-001:** `bin/setup` generates valid `.env` with cryptographic secrets on first run
- [ ] **EC-002:** `bin/setup` detects missing Docker/Compose and shows install instructions
- [ ] **EC-003:** `docker compose up -d` starts all services (api, dashboard, mcp, db, redis) without errors
- [ ] **EC-004:** `bin/check` reports all services healthy after startup
- [ ] **EC-005:** SMTP port bound to `127.0.0.1` by default (not `0.0.0.0`)
- [ ] **EC-006:** All services restart automatically after host reboot (`unless-stopped`)

### Logging

- [ ] **EC-007:** Rails API logs are structured JSON to stdout in production
- [ ] **EC-008:** SMTP server logs are structured JSON to stdout
- [ ] **EC-009:** Log level configurable via `RAILS_LOG_LEVEL` env var

### CI/CD

- [ ] **EC-010:** Push to `main` triggers Docker build + push to ghcr.io
- [ ] **EC-011:** Git tag `v*` triggers Docker build with version tag
- [ ] **EC-012:** Images built for both `linux/amd64` and `linux/arm64`
- [ ] **EC-013:** `docker pull ghcr.io/.../api:latest` works on both architectures

### Documentation

- [ ] **EC-014:** README quickstart works on a clean machine (clone → setup → up → dashboard loads)
- [ ] **EC-015:** Self-hosting guide covers full VPS walkthrough including firewall rules
- [ ] **EC-016:** DNS guide includes A, MX, SPF records with provider-specific examples
- [ ] **EC-017:** Configuration guide documents every environment variable
- [ ] **EC-018:** Upgrading guide covers `docker compose` update + rollback

### Landing Page

- [ ] **EC-019:** Landing page loads in <1s on 3G connection (no JavaScript)
- [ ] **EC-020:** Landing page renders correctly on mobile (responsive)
- [ ] **EC-021:** Open Graph meta tags render preview card when shared on Twitter/LinkedIn
- [ ] **EC-022:** "Get Started" links to quickstart, "GitHub" links to repo

### The 10-Minute Test

- [ ] **EC-023:** A new user completes the full flow (clone → setup → up → send email → see in dashboard) in under 10 minutes, following only the README quickstart

## 13. Open Questions

None — all decisions captured in ADRs 017, 018, and 019.
