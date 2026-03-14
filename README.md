# [@] inboxed

> Your emails go nowhere. You see everything.

**Inboxed** is a self-hosted SMTP server built for developers and QA automation. Point your app at it, send test emails, and inspect them via dashboard, REST API, or MCP — without any emails ever reaching a real inbox.

```
action_mailer → mail.notdefined.dev:587 → inboxed → REST API / MCP / dashboard
```

[![License: MIT](https://img.shields.io/badge/License-MIT-39FF14.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-3.3+-CC342D.svg)](https://ruby-lang.org)
[![Node](https://img.shields.io/badge/Node-20+-339933.svg)](https://nodejs.org)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED.svg)](docker-compose.yml)

---

## Why Inboxed?

Every developer has been here: your test needs the OTP from the signup email, but getting it means polling a real inbox, paying for a cloud service with rate limits, or hardcoding a bypass. None of those are good.

Inboxed gives you:

- A **real SMTP server** your staging app actually sends to
- An **inbox per email address** — no shared pool, no cross-test contamination
- A **REST API** so your tests can programmatically fetch emails
- A **MCP server** so AI agents and Claude Code can read emails without leaving their context
- A **dashboard** for when you just want to look at the HTML

---

## Quick Start

```bash
# 1. Clone
git clone https://github.com/notdefined-dev/inboxed
cd inboxed

# 2. Configure
cp .env.example .env
# edit .env: set INBOXED_DOMAIN, INBOXED_ADMIN_TOKEN

# 3. Run
docker compose up -d

# 4. Point your app at it
# Rails example:
config.action_mailer.smtp_settings = {
  address:  'localhost',     # or mail.notdefined.dev in staging
  port:      1587,
  user_name: 'myproject',   # your project name
  password:  'your-api-key' # generated in the dashboard
}
```

Dashboard available at `http://localhost:3200`

---

## Features

### SMTP Reception
- Accepts any email addressed to your configured domain
- Full MIME parsing — HTML, plain text, attachments, inline images
- TLS support (STARTTLS on 587, SSL on 465)
- Auth via API key per project
- **Not** an open relay — only accepts mail for registered domains

### REST API
```bash
# List emails in an inbox
GET /api/v1/inboxes/:address

# Get a specific email
GET /api/v1/emails/:id

# Get just the body
GET /api/v1/emails/:id/body

# Search
GET /api/v1/search?q=OTP&inbox=signup@test.local

# Wait for an email (long poll, up to 30s)
POST /api/v1/wait
{ "inbox": "signup@test.local", "subject_pattern": "verify" }

# Delete
DELETE /api/v1/emails/:id
DELETE /api/v1/inboxes/:address
```

### MCP Server
Works with Claude, Claude Code, n8n, and any MCP-compatible agent.

```json
{
  "mcpServers": {
    "inboxed": {
      "command": "node",
      "args": ["/path/to/inboxed-mcp/index.js"],
      "env": {
        "INBOXED_URL": "http://localhost:3000",
        "INBOXED_API_KEY": "your-api-key"
      }
    }
  }
}
```

Available tools:
- `get_latest_email(inbox, subject_pattern?)` 
- `wait_for_email(inbox, subject_pattern, timeout_seconds)`
- `extract_otp(inbox, pattern?)` — returns the numeric/alphanumeric code
- `extract_link(inbox, link_pattern?)` — returns first matching URL
- `list_emails(inbox, limit)`
- `delete_inbox(inbox)`
- `search_emails(query)`

### Dashboard
- Real-time inbox updates via Hotwire Turbo Streams
- HTML email preview (sandboxed iframe)
- Raw MIME source view
- Full-text search
- Project and API key management
- Configurable TTL per project

---

## Playwright Integration

```typescript
// helpers/inboxed.ts
import { InboxedClient } from '@inboxed/playwright';

const mail = new InboxedClient({
  url: process.env.INBOXED_URL,
  apiKey: process.env.INBOXED_API_KEY,
});

// In your test:
await page.fill('[name=email]', 'signup+test123@mail.notdefined.dev');
await page.click('[type=submit]');

const otp = await mail.extractOtp('signup+test123@mail.notdefined.dev');
await page.fill('[name=otp]', otp);
```

## RSpec Integration

```ruby
# spec/support/inboxed.rb
require 'inboxed/rspec'

# In your spec:
it 'sends a verification email' do
  post '/signup', params: { email: 'user@mail.notdefined.dev' }
  
  email = Inboxed.wait_for_email('user@mail.notdefined.dev', subject: /verify/)
  expect(email.subject).to include('Verify')
  
  otp = Inboxed.extract_otp('user@mail.notdefined.dev')
  expect(otp).to match(/\d{6}/)
end
```

---

## Configuration

```bash
# .env.example

# Required
INBOXED_DOMAIN=mail.notdefined.dev   # domain for inbound SMTP
INBOXED_ADMIN_TOKEN=changeme          # dashboard admin token
DATABASE_URL=postgresql://...

# Optional
INBOXED_SMTP_PORT=587          # default: 587
INBOXED_DEFAULT_TTL_HOURS=168  # default: 7 days
INBOXED_MAX_EMAILS_PER_PROJECT=10000
INBOXED_MAX_MESSAGE_SIZE_MB=25
INBOXED_MCP_PORT=3001
```

---

## Self-Hosting

### DNS Setup

```
# Add to your DNS provider (Cloudflare recommended)
A      mail.yourdomain.com   →   YOUR_VPS_IP      (proxy: OFF)
MX     mail.yourdomain.com   →   mail.yourdomain.com   priority: 10
TXT    mail.yourdomain.com   →   v=spf1 ip4:YOUR_VPS_IP ~all
CNAME  inboxed.yourdomain.com →  your-tunnel.cfargotunnel.com
```

> **Note on Hetzner:** Port 25 outbound may be restricted. Use port 587 as your primary SMTP port — all modern clients support it and it's the recommended submission port.

### Docker Compose

```yaml
services:
  inboxed:
    image: ghcr.io/notdefined-dev/inboxed:latest
    ports:
      - '587:587'
      - '465:465'
      - '3000:3000'
    environment:
      DATABASE_URL: postgresql://postgres:postgres@postgres/inboxed
      INBOXED_DOMAIN: mail.yourdomain.com
      INBOXED_ADMIN_TOKEN: ${INBOXED_ADMIN_TOKEN}
    depends_on: [postgres, redis]

  inboxed-mcp:
    image: ghcr.io/notdefined-dev/inboxed-mcp:latest
    ports:
      - '3001:3001'
    environment:
      INBOXED_API_URL: http://inboxed:3000
      INBOXED_API_KEY: ${INBOXED_MCP_KEY}

  postgres:
    image: postgres:16-alpine
    volumes: ['pgdata:/var/lib/postgresql/data']
    environment:
      POSTGRES_DB: inboxed
      POSTGRES_PASSWORD: postgres

  redis:
    image: redis:7-alpine

volumes:
  pgdata:
```

---

## Project Structure

```text
inboxed/
├── apps/
│   ├── web/          # Rails 8 — API, Dashboard, SMTP handler
│   └── mcp/          # Node.js MCP server
├── config/
│   └── deploy.yml    # Kamal deploy configuration
├── docs/             # Specs, branding, architecture
├── .devcontainer/    # Dev environment (Dockerfile, compose, etc.)
├── docker-compose.yml  # Production / self-hosting
└── .env.example
```

## Stack

| Layer | Technology |
|-------|-----------|
| Web + API | Ruby on Rails 8, Hotwire |
| SMTP server | ActionMailbox + custom SMTP handler |
| MCP server | Node.js 22 + TypeScript |
| Database | PostgreSQL 16 |
| Background jobs | Solid Queue |
| Real-time | Turbo Streams + ActionCable |
| Deploy | Docker + Kamal |

---

## Roadmap

- [x] SMTP reception + persistence
- [x] REST API with API key auth
- [x] Dashboard with real-time updates
- [x] MCP server
- [x] Playwright + RSpec helpers
- [ ] Webhooks on email received
- [ ] Routing rules (forward, drop, auto-reply)
- [ ] SMTP relay mode (capture + optional release)
- [ ] CLI (`inboxed list`, `inboxed wait`, `inboxed clear`)
- [ ] Email HTML preview with multi-client simulation
- [ ] Load testing mode

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs welcome — especially for SDK integrations in other languages/frameworks.

## Security

See [SECURITY.md](SECURITY.md) for responsible disclosure guidelines.

## License

[MIT](LICENSE.md) — © 2025 Adrian / notdefined.dev
