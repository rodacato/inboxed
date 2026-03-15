# ADR-011: Real-time Updates via ActionCable + Solid Cable

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner, Full-Stack Engineer, Security Engineer, API Design Architect

## Context

The dashboard needs to show emails arriving in real-time — when an SMTP message is processed, it should appear in the inbox list without a page refresh. The system already has an event store with a synchronous bus that dispatches domain events (`EmailReceived`, `EmailDeleted`, `InboxPurged`). We need a mechanism to push these events to connected dashboard clients.

Requirements:
1. **Low latency** — emails should appear within 1-2 seconds of SMTP receipt
2. **Scoped** — clients only receive updates for the inbox/project they're viewing
3. **Authenticated** — no unauthenticated WebSocket connections
4. **No new dependencies** — prefer what's already in the stack

### Options Considered

**A: Server-Sent Events (SSE)**
- Pro: Simple, HTTP-based, no special protocol. Works through proxies.
- Con: Unidirectional (server→client only). No built-in Rails support — would need a custom controller with streaming response. Connection management is manual. Can't easily scope to channels.

**B: ActionCable WebSocket (with solid_cable)**
- Pro: Already in the Rails stack (`solid_cable` gem in Gemfile, uses DB as pub/sub backend). Built-in channel abstraction for scoping. Authentication hooks on connection. Battle-tested in Rails ecosystem. Bi-directional if needed later.
- Con: WebSocket protocol adds complexity. `solid_cable` uses DB polling (not as fast as Redis pub/sub). Svelte dashboard needs a WebSocket client (no Hotwire/Turbo integration).

**C: Polling from dashboard**
- Pro: Zero server-side changes. Dashboard polls `GET /admin/.../emails` every N seconds.
- Con: Wasteful. Latency = poll interval. Doesn't scale with many open tabs. Poor UX.

**D: Redis pub/sub with custom WebSocket**
- Pro: Fast, proven at scale.
- Con: Adds Redis as a hard dependency for real-time only. Over-engineered for a dev tool.

## Decision

**ActionCable with solid_cable (B).**

### Rationale

1. **Already in the stack** — `solid_cable` is in the Gemfile and configured. Zero new dependencies.
2. **Channel abstraction** — `InboxChannel` and `ProjectChannel` provide natural scoping. A client subscribes to a specific inbox and only gets updates for that inbox.
3. **Auth on connection** — ActionCable's `connect` method validates the admin token before accepting the WebSocket. Unauthenticated connections are rejected.
4. **Event store integration** — The existing `EventStore::Bus` dispatches events synchronously. Adding a subscriber that broadcasts to ActionCable is a one-liner per event type.
5. **solid_cable latency** — DB-backed polling has ~100ms latency. For a dev tool dashboard, this is imperceptible. Redis can be swapped in later via config if needed.

### Architecture

```
SMTP → ReceiveEmailJob → ReceiveEmail service → EventStore.publish
                                                       │
                                                  Bus.dispatch
                                                       │
                                              ┌────────┴────────┐
                                              │                 │
                                    (existing handlers)   ActionCable
                                                         Broadcaster
                                                              │
                                                    ┌─────────┴─────────┐
                                                    │                   │
                                           InboxChannel          ProjectChannel
                                           (email events)      (inbox events)
                                                    │                   │
                                              Dashboard           Dashboard
                                           (inbox view)       (project view)
```

### Channels

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :admin_authenticated

    def connect
      self.admin_authenticated = authenticate_admin
    end

    private

    def authenticate_admin
      token = request.params[:token]
      admin_token = ENV["INBOXED_ADMIN_TOKEN"]
      reject_unauthorized_connection unless token.present? &&
        ActiveSupport::SecurityUtils.secure_compare(token, admin_token)
      true
    end
  end
end
```

```ruby
# app/channels/inbox_channel.rb
class InboxChannel < ApplicationCable::Channel
  def subscribed
    stream_from "inbox_#{params[:inbox_id]}"
  end
end
```

```ruby
# app/channels/project_channel.rb
class ProjectChannel < ApplicationCable::Channel
  def subscribed
    stream_from "project_#{params[:project_id]}"
  end
end
```

### Event Store Integration

```ruby
# config/initializers/event_subscriptions.rb
Rails.application.config.after_initialize do
  Inboxed::EventStore::Bus.subscribe(Inboxed::Events::EmailReceived) do |event|
    email = EmailRecord.find_by(id: event.data[:email_id])
    next unless email

    ActionCable.server.broadcast("inbox_#{event.data[:inbox_id]}", {
      type: "email_received",
      email: { id: email.id, from: email.from_address, subject: email.subject,
               received_at: email.received_at.iso8601 }
    })

    ActionCable.server.broadcast("project_#{email.inbox.project_id}", {
      type: "inbox_updated",
      inbox: { id: event.data[:inbox_id], email_count_delta: 1 }
    })
  end

  Inboxed::EventStore::Bus.subscribe(Inboxed::Events::EmailDeleted) do |event|
    ActionCable.server.broadcast("inbox_#{event.data[:inbox_id]}", {
      type: "email_deleted",
      email_id: event.data[:email_id]
    })
  end

  Inboxed::EventStore::Bus.subscribe(Inboxed::Events::InboxPurged) do |event|
    ActionCable.server.broadcast("inbox_#{event.data[:inbox_id]}", {
      type: "inbox_purged",
      deleted_count: event.data[:deleted_count]
    })
  end
end
```

### Dashboard Client (Svelte)

The dashboard connects via a plain WebSocket client — no Turbo or Stimulus needed:

```typescript
// src/lib/cable-client.ts
export function createCableConnection(token: string) {
  const url = `${wsBase()}/cable?token=${encodeURIComponent(token)}`;
  return new WebSocket(url);
}

export function subscribeToInbox(ws: WebSocket, inboxId: string, onMessage: (data: any) => void) {
  // ActionCable protocol: subscribe command
  ws.send(JSON.stringify({
    command: "subscribe",
    identifier: JSON.stringify({ channel: "InboxChannel", inbox_id: inboxId })
  }));
  // Handle incoming messages
  ws.addEventListener("message", (event) => {
    const msg = JSON.parse(event.data);
    if (msg.identifier && JSON.parse(msg.identifier).channel === "InboxChannel") {
      onMessage(msg.message);
    }
  });
}
```

## Consequences

### Easier

- **Instant email appearance** — emails show up in the dashboard as soon as they're processed
- **Scoped updates** — no wasted bandwidth, clients only get relevant events
- **No new dependencies** — solid_cable is already configured
- **Event store synergy** — real-time is a natural extension of the existing event bus

### Harder

- **WebSocket client in Svelte** — must implement ActionCable protocol manually (subscribe/unsubscribe JSON messages). No official Svelte adapter.
- **Connection management** — must handle reconnection, token expiry, tab visibility
- **Testing** — ActionCable integration tests require WebSocket test helpers

### Mitigations

- ActionCable protocol is simple (3 message types: subscribe, unsubscribe, message). A thin `cable-client.ts` wrapper (~50 lines) handles it.
- Reconnection: on WebSocket close, reconnect with exponential backoff (1s, 2s, 4s, max 30s).
- Testing: use `ActionCable.server.broadcast` directly in tests, verify via channel test helpers.

## Revisit When

- solid_cable latency becomes noticeable → switch to Redis adapter (config change only)
- Need server-side push to external systems (webhooks) → separate concern, not ActionCable
