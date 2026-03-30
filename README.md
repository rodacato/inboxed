# [@] Inboxed

> **This project is archived and no longer maintained.**

---

### Lessons Learned

This project set out to build a self-hosted dev inbox with native MCP server integration, enabling AI agents (like Claude) to programmatically extract OTPs, verification links, and email content during automated E2E testing flows.

**The idea works and is useful** — the SMTP capture, REST API, dashboard, and MCP tooling all function as designed. However, the primary use case that motivated this project — having Claude register on services and complete E2E flows autonomously — hit a fundamental blocker:

- **AI agents cannot self-register on websites.** Claude (and similar agents) have built-in safety restrictions that prevent them from completing signup/registration flows, even on `localhost` or self-hosted services. This means the core workflow of "Claude signs up → receives verification email → extracts OTP via MCP → completes registration" is not feasible with current AI agent policies.
- **MCP integration is solid but underserved by its intended consumer.** The MCP server works well for manual or semi-automated workflows, but the fully autonomous agent-driven E2E testing loop it was designed for cannot be closed due to the registration restriction above.
- **Scope vs. utility trade-off.** For simpler use cases (catching test emails, inspecting webhooks), existing tools like Mailpit or MailHog are sufficient and battle-tested. Inboxed's differentiator was the MCP layer for AI agents, which is currently blocked at the policy level, not the technical level.

**If AI agent policies evolve** to allow controlled self-registration in sandboxed/dev environments, this project (or its approach) could become highly relevant again.

---

> Your emails go nowhere. You see everything.

**Inboxed** is a self-hosted dev inbox for emails, webhooks, and HTTP requests. Catch test emails, inspect webhooks, and let AI agents extract OTPs via MCP.

[![License: MIT](https://img.shields.io/badge/License-MIT-39FF14.svg)](LICENSE.md)
[![Ruby](https://img.shields.io/badge/Ruby-3.3+-CC342D.svg)](https://ruby-lang.org)
[![Node](https://img.shields.io/badge/Node-22+-339933.svg)](https://nodejs.org)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED.svg)](docker-compose.yml)

## Quickstart

```bash
git clone https://github.com/rodacato/inboxed && cd inboxed
bin/setup
docker compose up -d
```

Open `http://localhost/setup` to create your admin account, then `http://localhost` for the dashboard.

## Features

- **SMTP server** — point your app's SMTP config, catch all test emails
- **HTTP hooks** — catch webhooks, form submissions, and heartbeats
- **REST API** — list, search, wait for emails and requests programmatically
- **Dashboard** — real-time inbox viewer with search, OTP detection, and email preview
- **MCP server** — AI agents extract OTPs, links, and webhook data via Model Context Protocol

## MCP Server

Works with Claude Code, Cursor, n8n, and any MCP-compatible agent.

```json
{
  "mcpServers": {
    "inboxed": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm", "--network", "host",
        "-e", "INBOXED_API_URL=http://localhost:3100",
        "-e", "INBOXED_API_KEY=<your-api-key>",
        "ghcr.io/rodacato/inboxed-mcp"
      ]
    }
  }
}
```

15 tools available: `list_emails`, `get_email`, `wait_for_email`, `extract_code`, `extract_link`, `extract_value`, `search_emails`, `delete_inbox`, `create_endpoint`, `wait_for_request`, `get_latest_request`, `extract_json_field`, `list_requests`, `check_heartbeat`, `delete_endpoint`

## REST API

```bash
# Wait for an email (long-polling)
curl -X POST http://localhost:3100/api/v1/emails/wait \
  -H "Authorization: Bearer <api-key>" \
  -d "to=signup@test" \
  -d "timeout=30"

# List emails
curl http://localhost:3100/api/v1/inboxes/<id>/emails \
  -H "Authorization: Bearer <api-key>"
```

## Architecture

```
apps/
├── api/           # Rails 8 API + SMTP server (midi-smtp-server)
├── dashboard/     # Svelte 5 SPA + Tailwind 4
└── mcp/           # Node.js MCP server (TypeScript)
```

| Layer | Technology |
|-------|-----------|
| API | Ruby on Rails 8 |
| SMTP | midi-smtp-server gem |
| MCP | Node.js 22, TypeScript, MCP SDK |
| Database | PostgreSQL 16 |
| Jobs | Solid Queue |
| Real-time | ActionCable |
| Dashboard | Svelte 5, Tailwind 4 |
| Deploy | Docker Compose, Kamal |

## Self-Hosting

See the [Self-Host Guide](https://inboxed.notdefined.dev/self-host) for step-by-step instructions covering:

- **Local setup** — Docker Compose on your machine
- **Production** — VPS with HTTPS (Caddy or Cloudflare Tunnel), DNS, and optional inbound email
- **Kamal deploy** — zero-downtime deploys from a fork

Configuration reference: [`.env.example`](.env.example)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE.md)
