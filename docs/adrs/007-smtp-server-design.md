# ADR-007: SMTP Server Design — Separate Process with Async Processing

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

Inboxed needs an SMTP server to receive emails from applications under test. The SMTP server must authenticate connections, receive MIME messages, and persist them. The design decisions are:

1. **Process model** — Should the SMTP server run inside the Rails web process (Puma) or as a separate process?
2. **Processing model** — Should email processing happen synchronously during the SMTP session or asynchronously after?
3. **Library choice** — Which Ruby SMTP server library to use?

## Options

### Process Model

**A: In-process (inside Puma)**
- SMTP server starts as a thread alongside Puma workers.
- Pro: Single process to manage.
- Con: SMTP and HTTP compete for resources. A slow SMTP session blocks a Puma worker. SMTP requires long-lived connections, HTTP is request/response.

**B: Separate process (Procfile)**
- SMTP server runs as its own process, managed by Procfile/systemd/Docker.
- Pro: Independent scaling. SMTP can use its own thread pool. Crash isolation.
- Con: Additional process to manage. Needs shared database access.

### Processing Model

**A: Synchronous (process during DATA)**
- Parse MIME, persist to DB, publish events — all during the SMTP DATA command.
- Pro: Simple. Client knows immediately if processing failed.
- Con: Slow SMTP sessions. Client blocks during DB writes and MIME parsing. No retry on failure.

**B: Asynchronous (enqueue job on DATA)**
- Enqueue raw message to Solid Queue, return 250 OK immediately.
- Pro: Fast SMTP sessions. Retry semantics for free. SMTP server stays responsive.
- Con: Small delay before email appears. Client gets 250 OK even if processing later fails.

### Library Choice

**A: `midi-smtp-server` gem**
- Mature Ruby SMTP server. Event-based API (on_auth, on_mail_from, on_rcpt_to, on_message_data). TLS support. AUTH support.
- Pro: Well-maintained, good API, handles protocol details.
- Con: Ruby-only, single-threaded per connection.

**B: Custom implementation with `TCPServer`**
- Build SMTP protocol handling from scratch.
- Pro: Full control, learning opportunity.
- Con: SMTP is complex (AUTH, TLS, MIME). Would take weeks to get right. Not the focus of this project.

**C: Go sidecar**
- Write SMTP server in Go, communicate with Rails via HTTP/gRPC.
- Pro: Excellent concurrency. Go's `net/smtp` is battle-tested.
- Con: Two languages, deployment complexity, cross-process communication overhead.

## Decision

**Separate process + async processing + `midi-smtp-server`.**

### Rationale

1. **Separate process** because SMTP and HTTP have fundamentally different connection patterns. HTTP is request/response, SMTP is conversational with long-lived connections. Mixing them in one process creates resource contention and makes crash isolation impossible.

2. **Async processing** because the SMTP server's job is to receive mail reliably, not to parse and persist it. Enqueuing to Solid Queue gives us:
   - Fast SMTP response times (<10ms to acknowledge)
   - Automatic retry if parsing or persistence fails
   - Backpressure handling (queue depth monitoring)
   - The SMTP server stays responsive under load

3. **`midi-smtp-server`** because it handles the SMTP protocol correctly (AUTH, TLS, multi-recipient, size limits) and provides a clean event-based API. Building SMTP from scratch is a multi-week distraction from the actual product. Go is reserved for post-MVP if Ruby's SMTP performance becomes a bottleneck (per IDENTITY.md).

### Process Layout

```
Procfile:
  web:    Puma (HTTP API)        → port 3000
  smtp:   midi-smtp-server       → port 2525 (dev), 587/465 (prod)
  worker: Solid Queue            → processes ReceiveEmailJob
```

All three processes share the same Rails application code and database.

## Consequences

- Three processes in development (web, smtp, worker) — managed by Procfile or overmind
- Docker Compose needs a service entry for the SMTP process
- Solid Queue must be running for emails to be processed (worker process)
- If Solid Queue is down, emails are acknowledged by SMTP but not processed until the worker restarts (messages are in the queue table)
- Kamal deployment needs the SMTP process as an additional service or accessory
- Port 2525 must be forwarded in devcontainer configuration

## Revisit When

- SMTP performance requires more than `midi-smtp-server` can handle → consider Go sidecar
- Self-hosting users want a single-process deployment → consider in-process mode as an option
