# Changelog

All notable changes to Inboxed will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

_Nothing yet._

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

#### Client Libraries
- Ruby RSpec helper (`inboxed` gem)
- TypeScript/Playwright helper (`inboxed` npm package)

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
