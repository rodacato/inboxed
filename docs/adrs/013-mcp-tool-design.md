# ADR-013: MCP Tool Design & Extraction Strategy

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

The MCP server exposes tools to AI agents for reading and extracting data from captured emails. Two categories of tools exist:

1. **CRUD tools** — list, get, search, delete (thin wrappers around the REST API)
2. **Extraction tools** — `extract_code`, `extract_link`, and `extract_value` (require parsing email bodies to find specific content)

The key question is: **where does extraction logic live?**

### Options Considered

**A: Extraction in the Rails API (new endpoints)**
- Pro: Centralized logic, reusable by dashboard and future SDKs
- Pro: Ruby has mature email/HTML parsing libraries
- Con: Adds endpoints that only MCP needs right now, violating YAGNI
- Con: Couples API evolution to MCP-specific use cases

**B: Extraction in the MCP server (TypeScript)**
- Pro: Self-contained — MCP server owns its value-add logic
- Pro: No changes needed to the Rails API
- Pro: Extraction patterns are simple (regex on text body), not worth an HTTP round-trip
- Con: Duplicates logic if other clients want extraction later

**C: Hybrid — basic extraction in MCP, promote to API when needed**
- Pro: Start simple, evolve when there's demand
- Con: Slightly ambiguous ownership

## Decision

**Option B** — extraction logic lives in the MCP server.

### Rationale

- Code extraction is a regex match on the plain-text body (`\b\d{4,8}\b`, or user-supplied pattern). This is 5-10 lines of code, not worth a network round-trip or a new API endpoint.
- Link extraction is similarly simple: parse `href` attributes or match URLs in plain text.
- Value extraction (labeled data like temporary passwords, usernames, reference numbers) is a label-based regex search (`{label}[:\s]+(.+)`). Same simplicity.
- The MCP server already fetches the full email body via `GET /api/v1/emails/:id`. Extraction is a local post-processing step.
- If the dashboard or SDKs need extraction later, we promote the logic to the API (Option C emerges naturally).

### Extraction Tool Taxonomy

Three extraction tools cover all common email testing patterns:

| Tool | What it extracts | Default behavior |
|------|-----------------|------------------|
| `extract_code` | Verification codes, 2FA codes, OTPs, confirmation codes | Matches `\b\d{4,8}\b`, supports custom regex |
| `extract_link` | Verification URLs, magic links, reset links | Matches `https?://` URLs, optional pattern filter |
| `extract_value` | Any labeled value: temp passwords, usernames, reference numbers | Searches for `{label}: {value}` patterns in body |

The naming is intentional:
- `extract_code` (not `extract_otp`) — "code" is the umbrella term for verification codes, auth codes, confirmation codes, and OTPs. More accurate and discoverable for agents.
- `extract_value` — a generic catch-all for any structured `label: value` pair in an email. Avoids proliferating tools for each data type (passwords, usernames, order numbers, etc.).

### Tool Design Principles

1. **Inbox addressed by email address, not UUID** — AI agents know the email address they sent to, not internal UUIDs. Tools accept `inbox` as a string (e.g., `test@mail.inboxed.dev`). The MCP server resolves the address to an inbox ID via the API.
2. **Sensible defaults** — `limit` defaults to 10, `timeout_seconds` defaults to 30, code pattern defaults to `\b\d{4,8}\b`.
3. **Plain text first** — extraction operates on `body_text` when available, falls back to stripped `body_html`. HTML parsing is a last resort.
4. **Structured output** — tools return structured objects (not raw strings) so agents can programmatically use results.

## Consequences

### Easier

- **No API changes needed** — MCP server ships independently of the Rails API
- **Fast iteration** — extraction patterns can be refined without API deploys
- **Testing** — extraction is pure functions, trivially unit-testable
- **Agent UX** — tools accept human-readable inbox addresses, not UUIDs

### Harder

- **Logic duplication** — if dashboard adds "copy code" feature, extraction logic would need to be reimplemented in the Rails side
- **Consistency** — extraction behavior could diverge between MCP and future clients

### Mitigations

- Extraction logic is simple enough that reimplementation is trivial
- Document the extraction patterns in the spec so all clients can stay consistent
- Promote to API endpoint when a second client needs it (YAGNI until then)

### Revisit When

- The dashboard or an SDK client needs code/link/value extraction
- Extraction patterns become complex enough to warrant server-side processing (e.g., ML-based extraction)
