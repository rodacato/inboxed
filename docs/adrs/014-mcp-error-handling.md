# ADR-014: MCP Error Handling & Timeout Strategy

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

MCP tools call the Inboxed REST API over HTTP. Several failure modes exist:

1. **API unreachable** — network error, server down
2. **Authentication failure** — invalid or expired API key
3. **Resource not found** — inbox address doesn't exist, email deleted
4. **Timeout on wait** — `wait_for_email` long-poll expires without a match
5. **Rate limited** — Rack::Attack returns 429

AI agents consuming MCP tools need **clear, actionable error messages** — not stack traces or generic "something went wrong" responses. The agent must understand what happened and whether retrying makes sense.

### Options Considered

**A: Throw exceptions, let MCP SDK handle errors**
- Pro: Simple, zero custom error handling
- Con: Agents see raw error messages, poor UX
- Con: No distinction between retryable and terminal errors

**B: Structured error responses with `isError` flag**
- Pro: MCP SDK supports `isError: true` in tool results — agents can distinguish success from failure
- Pro: Error messages can be crafted for agent consumption
- Pro: Can include retry hints and context
- Con: More code per tool

**C: Retry internally in the MCP server**
- Pro: Agents see fewer transient errors
- Con: Hides failures, increases latency unpredictably
- Con: Retry logic is complex (backoff, idempotency)

## Decision

**Option B** — structured error responses using MCP SDK's `isError` convention.

### Error Response Format

Tools return errors as structured content with `isError: true`:

```typescript
return {
  content: [{ type: "text", text: "Inbox not found: test@mail.inboxed.dev" }],
  isError: true,
};
```

### Error Categories

| API Status | MCP Behavior | Message Pattern |
|------------|-------------|-----------------|
| 401/403 | `isError: true` | "Authentication failed. Check INBOXED_API_KEY." |
| 404 | `isError: true` | "Inbox not found: {address}" or "Email not found: {id}" |
| 408/timeout | `isError: true` | "No matching email arrived within {n} seconds." |
| 422 | `isError: true` | "Invalid input: {details}" |
| 429 | `isError: true` | "Rate limited. Try again in {n} seconds." |
| 500+ | `isError: true` | "Inboxed API error ({status}). The server may be temporarily unavailable." |
| Network error | `isError: true` | "Cannot reach Inboxed API at {url}. Check INBOXED_API_URL." |

### Principles

1. **No internal retries** — the MCP server does not retry failed API calls. The AI agent (or its orchestrator) decides whether to retry. This keeps behavior predictable and latency transparent.
2. **Agent-readable messages** — error messages are written for AI agents, not humans. They include the specific input that failed and suggest corrective action.
3. **Timeout is not an error for `wait_for_email`** — when the wait expires without a match, return a structured "no email found" result with `isError: false`. The agent can decide to wait again. Only network/auth failures during the wait are `isError: true`.
4. **Centralized error mapping** — a single helper function maps API HTTP errors to MCP error responses. Tools don't handle HTTP status codes directly.

## Consequences

### Easier

- **Agent debugging** — clear messages tell the agent exactly what went wrong and what to try
- **Predictable latency** — no hidden retries, timeout is what you set
- **Consistent error format** — all tools use the same error mapping helper

### Harder

- **Every tool needs error handling** — each tool must catch and map errors (mitigated by the shared helper)
- **Agents must handle retries** — no automatic recovery from transient errors

### Mitigations

- Shared `mapApiError(error): ToolResult` helper keeps tool code DRY
- Document error categories in the spec so agent developers know what to expect
- The `wait_for_email` timeout-is-not-error convention avoids false alarm loops
