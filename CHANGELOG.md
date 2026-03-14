# Changelog

All notable changes to Inboxed will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added
- Initial SMTP reception server (ActionMailbox + custom SMTP handler)
- REST API v1: inboxes, emails, search, wait endpoint
- Dashboard with Hotwire real-time updates
- MCP server with `get_latest_email`, `wait_for_email`, `extract_otp`, `extract_link`, `list_emails`, `delete_inbox`, `search_emails`
- Multi-project support with API key auth per project
- Configurable TTL per project
- Docker Compose setup for self-hosting
- Playwright TypeScript helper
- RSpec helper
- `mail.notdefined.dev` SMTP + `inboxed.notdefined.dev` dashboard

---

## Version History

_No stable releases yet. See [Unreleased] above._

---

<!-- template for future releases:

## [0.1.0] - YYYY-MM-DD

### Added
- 

### Changed
- 

### Fixed
- 

### Removed
- 

-->
