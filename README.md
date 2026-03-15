# [@] Inboxed

> Your emails go nowhere. You see everything.

**Inboxed** is a self-hosted SMTP server for developers and QA. Catch test emails, inspect them via API or dashboard, and extract OTPs from AI agents via MCP.

[![License: MIT](https://img.shields.io/badge/License-MIT-39FF14.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-3.3+-CC342D.svg)](https://ruby-lang.org)
[![Node](https://img.shields.io/badge/Node-22+-339933.svg)](https://nodejs.org)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED.svg)](docker-compose.yml)

## Quickstart

```bash
git clone https://github.com/notdefined-dev/inboxed && cd inboxed
bin/setup
docker compose up -d
```

Open http://localhost — your dashboard is ready.

Send a test email:

```bash
swaks --to test@localhost --server localhost:587
```

## Features

- **SMTP server** — point your app's SMTP config, catch all test emails
- **REST API** — list, search, wait for emails programmatically
- **Dashboard** — real-time inbox viewer with search and OTP detection
- **MCP server** — AI agents extract OTPs and links without leaving context
- **Client libraries** — [TypeScript](packages/typescript/) and [Ruby](packages/ruby/) clients for test automation

## Test Automation

### Playwright / Vitest

```typescript
import { InboxedClient } from "inboxed";

const mail = new InboxedClient({ apiUrl: "http://localhost:3000" });

const code = await mail.extractCode("signup@mail.inboxed.dev");
await page.fill("[name=otp]", code);
```

### RSpec

```ruby
require "inboxed"

Inboxed.configure { |c| c.api_url = "http://localhost:3000" }

email = Inboxed.wait_for_email("user@mail.inboxed.dev", subject: /verify/)
code = Inboxed.extract_code("user@mail.inboxed.dev")
expect(code).to match(/\d{6}/)
```

## MCP Server

Works with Claude Code, Cursor, n8n, and any MCP-compatible agent.

```json
{
  "mcpServers": {
    "inboxed": {
      "command": "node",
      "args": ["apps/mcp/dist/index.js"],
      "env": {
        "INBOXED_API_URL": "http://localhost:3000",
        "INBOXED_API_KEY": "your-api-key"
      }
    }
  }
}
```

Tools: `list_emails`, `get_email`, `wait_for_email`, `extract_code`, `extract_link`, `extract_value`, `search_emails`, `delete_inbox`

## Documentation

- [Self-hosting guide](docs/guides/self-hosting.md)
- [DNS setup](docs/guides/dns-setup.md)
- [Configuration reference](docs/guides/configuration.md)
- [Upgrading](docs/guides/upgrading.md)
- [REST API spec](docs/specs/003-rest-api.md)
- [MCP tools spec](docs/specs/005-mcp-server.md)

## Architecture

```
apps/
├── api/           # Rails 8 API + SMTP server (midi-smtp-server)
├── dashboard/     # SvelteKit SPA + Tailwind 4
└── mcp/           # Node.js MCP server (TypeScript)
packages/
├── typescript/    # Zero-dep TypeScript client
└── ruby/          # Zero-dep Ruby client
```

| Layer | Technology |
|-------|-----------|
| API | Ruby on Rails 8 |
| SMTP | midi-smtp-server gem |
| MCP | Node.js 22, TypeScript, MCP SDK |
| Database | PostgreSQL 16 |
| Jobs | Solid Queue |
| Real-time | ActionCable |
| Dashboard | SvelteKit 2, Svelte 5, Tailwind 4 |
| Deploy | Docker Compose |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE.md)
