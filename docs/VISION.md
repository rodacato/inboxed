# Inboxed — Vision

> The dev inbox for everything your app sends and receives.

---

## The Problem

During development, your app talks to the outside world through multiple channels: it sends emails, receives webhooks, fires callbacks, expects external notifications. Today, debugging each of these requires a different tool:

| What you need to inspect | What you use today |
|---|---|
| Emails your app sends | Mailpit, Mailtrap, MailHog |
| Webhooks your app receives | webhook.site, RequestBin |
| Simulate a webhook hitting your app | curl + ngrok, Mockoon |
| See the full flow (email out → webhook in → response back) | ...nothing unified |

Every tool has its own setup, its own dashboard, its own API. None of them talk to each other. None of them have MCP integration.

## The Insight

These are all the same problem: **inspecting and simulating external communications during development**. The protocol differs (SMTP, HTTP), the direction differs (inbound, outbound), but the developer need is identical — catch it, store it, inspect it, assert on it.

## The Vision

Inboxed becomes the **unified dev inspector for external communications**. One self-hosted tool. One dashboard. One API. One MCP server.

```
Inboxed
├── Mail       Catch and inspect emails (SMTP → store → inspect)
├── Hooks In   Catch and inspect incoming webhooks (HTTP → store → inspect)
├── Hooks Out  Send webhooks to your app for testing (create → send → log response)
└── Relay      Receive a webhook → optionally transform → forward → log both sides
```

### What stays constant across all modules

- Belongs to a **Project** with API keys and TTL
- Inspectable via **REST API**, **Dashboard**, and **MCP**
- Real-time updates via **ActionCable**
- Self-hosted, single `docker-compose up`
- AI agents can interact with everything via MCP

### What differs per module

| | Mail | Hooks In | Hooks Out | Relay |
|---|---|---|---|---|
| **Protocol** | SMTP | HTTP (any method) | HTTP (any method) | HTTP → HTTP |
| **Direction** | App → Inboxed | External → Inboxed | Inboxed → App | External → Inboxed → App |
| **Trigger** | App sends email | Third party calls URL | User/schedule/event | Incoming request |
| **Stored data** | MIME, headers, body, attachments | Method, headers, body, query, IP | Request sent + response received | Both sides of the proxy |
| **Key use case** | "Did my app send the verification email?" | "What does the Stripe webhook payload look like?" | "Does my handler process this payload correctly?" | "I need to inspect production webhooks while still delivering them" |

## What This Is Not

- **Not a production email server.** Inboxed doesn't deliver email to real inboxes.
- **Not an API gateway.** No routing rules, no auth proxying, no rate limiting for your app.
- **Not an integration platform.** No Zapier-style workflow builder. Catch, inspect, assert — that's it.
- **Not a monitoring tool.** This is for development and testing, not production observability.

## Naming

"Inboxed" works for the broader vision. An inbox receives things — emails, requests, notifications. The brand identity ("catch, inspect, assert") and the retro terminal aesthetic apply equally to all modules.

Each module can be referenced as:
- **Inboxed Mail** (or just "Inboxed" when context is clear)
- **Inboxed Hooks**

No need to rename. No need for sub-brands.

## Execution Strategy

### Phase 1: Prove the core (now → public launch)

Build and ship **Inboxed Mail** (Phases 0-6 in the roadmap). This is the MVP, the differentiator (MCP), and the foundation. Everything else depends on this being solid.

### Phase 2: Extend the pattern (post-launch)

Add webhook modules (Phases 7-8+) once Mail is stable and has real users. The architecture of Projects, API keys, dashboard, MCP tools, and ActionCable will already exist — webhook modules plug into it.

### Phase 3: Let users tell you what's next

Maybe it's gRPC inspection. Maybe it's GraphQL subscription catching. Maybe it's something nobody has thought of yet. The modular architecture supports it, but we don't build it until there's demand.

## The Litmus Test

Before adding any new module or feature, ask:

1. **Is this about inspecting or simulating external dev communications?** If no, it's out of scope.
2. **Does it fit the "catch, inspect, assert" model?** If it needs workflow builders, routing engines, or production guarantees, it's a different product.
3. **Can an AI agent use it via MCP?** If the feature can't be expressed as an MCP tool, reconsider.
4. **Does it work with `docker-compose up`?** If it needs external services, managed infrastructure, or complex config, simplify.
