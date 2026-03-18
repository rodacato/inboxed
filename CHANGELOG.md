# Changelog

All notable changes to Inboxed will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

_Nothing yet._

---

## [0.2.0] - 2026-03-16

### Added

#### Core
- Multi-user data model with organizations, users, memberships, and roles
- Session-based cookie authentication with tenant isolation
- Invitation system for team member management
- HTTP Catcher module: public catch endpoint, management API, and heartbeat monitoring
- MCP server tools for HTTP Catcher (create, list, wait, extract, heartbeat)
- Project-level requests API with semantic token prefixes

#### Dashboard
- Auth pages (login, signup) with session-based cookie auth
- Member management, trial banner, and sidebar updates
- HTTP Catcher UI: unified hooks view with type filters (webhooks, forms, heartbeats)
- Button group filter redesign with two-line header layout
- Module-aware sidebar with per-module counts and real-time updates
- Settings hub with sidebar navigation and dedicated pages
- Tabbed Quick Start layout with real endpoint tokens in snippets
- Reusable layout primitives (SplitPane, FilterableList, EmptyState)
- Toast notifications and command palette UI
- Request detail view with parsed query params, copy buttons, and JSON formatting
- Landing page with Stitch-inspired design
- Privacy policy and terms of service pages
- Favicon generated from logo icon

#### Infrastructure
- Improved deploy workflow with pre-flight checks and consolidated jobs
- Separated SMTP and web domains with updated DNS guide
- Comprehensive specs for multi-user system (291 examples, 0 failures)
- Integration test script and testing guide

### Fixed
- Accept all HTTP verbs by default and fix body capture
- Dashboard reactivity and data mapping issues
- Setup flow bugs (param mismatch, missing transaction, stale state)
- Infinite redirect loop on login page
- Solid Queue/Cable/Cache schema loading in production
- Kamal deploy config issues and dashboard build errors
- ESLint errors (32 resolved)
- Critical and high-severity security findings
- Missing Caddy/vite proxy routes and post-setup onboarding flow
- Tailwind z-index bracket notation

### Changed
- Restructured dashboard routes with module tabs and /mail namespace
- Extracted shared services, removed dead code, deduplicated logic
- Aligned env vars across configs for unified multi-user model

---

## [0.1.0] - 2026-03-16

First public release of Inboxed — a developer-first email testing platform.

### Added

#### Core
- SMTP reception server with STARTTLS and implicit TLS support
- Multi-project support with API key authentication
- Configurable TTL per project with automatic email cleanup
- Domain event bus for internal pub/sub
- Solid Queue background job processing (in-Puma mode)

#### API
- REST API v1: projects, inboxes, emails, attachments, search
- Wait endpoint for polling-based email arrival
- Webhook endpoints with HMAC-SHA256 signed deliveries
- Admin token authentication

#### Dashboard
- Svelte 5 SPA with email-first unified layout
- 3-column split view: sidebar → email list → email preview
- HTML/Text/Raw/Headers tabs for email inspection
- OTP detection and one-click copy
- Inbox filter chips with color-coded badges
- Real-time updates via polling

#### MCP Server
- Model Context Protocol server for AI agent integration
- Tools: `get_latest_email`, `wait_for_email`, `extract_otp`, `extract_link`, `list_emails`, `delete_inbox`, `search_emails`

#### Client Libraries (unpublished)
- Ruby client (`packages/ruby/`) — not yet published to RubyGems
- TypeScript client (`packages/typescript/`) — not yet published to npm

#### Infrastructure
- Docker Compose setup for self-hosting
- Kamal deployment configuration with GitHub Actions CI/CD
- Cloudflared tunnel support (HTTP via tunnel, SMTP direct)
- Multi-arch Docker images (amd64 + arm64)
- Structured JSON logging with lograge
- Static landing page

#### Documentation
- Self-hosting guide (Docker Compose)
- Kamal deploy guide (GitHub Actions)
- DNS and cloudflared setup guide
- Upgrading guide
- Architecture specs and ADRs

---

<!-- template for future releases:

## [X.Y.Z] - YYYY-MM-DD

### Added
-

### Changed
-

### Fixed
-

### Removed
-

-->
