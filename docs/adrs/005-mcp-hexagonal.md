# ADR-005: Hexagonal Light for MCP Server

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

The MCP server is a tool server — it receives requests from AI agents (via MCP protocol) and translates them into Inboxed API calls. It has no domain logic of its own. The complexity lives in the Rails API; the MCP server is a thin adapter.

Over-architecting the MCP server (e.g., full DDD) would be wasteful. But having all code in a single `index.ts` won't scale as tools grow.

## Decision

Adopt a **hexagonal light** pattern: Tools + Ports.

### Directory Structure

```
apps/mcp/src/
├── tools/                       # One file per MCP tool
│   ├── list-messages.ts
│   ├── get-message.ts
│   ├── search-messages.ts
│   ├── wait-for-email.ts
│   ├── extract-otp.ts
│   └── extract-link.ts
├── ports/
│   └── inboxed-api.ts           # HTTP client for Inboxed REST API
├── types/
│   └── index.ts                 # Shared TypeScript interfaces
├── server.ts                    # MCP server setup + tool registration
└── index.ts                     # Entry point (connect transport)
```

### Rules

1. **Each tool is a single file** exporting a function with this signature:
   ```typescript
   export const toolDefinition = { name, description, inputSchema };
   export async function execute(input: Input, api: InboxedApi): Promise<Output>
   ```
2. **Tools are pure functions** — they receive input, call the port, return output. No side effects beyond the API call.
3. **The port (`inboxed-api.ts`) is the only file that knows HTTP.** It encapsulates base URL, auth headers, error handling, and response parsing.
4. **`server.ts` is the wiring layer** — it imports all tools, registers them with the MCP server, and injects the port.
5. **Zero state** — the MCP server is stateless. Each tool invocation is independent.
6. **Types are shared** — tool inputs/outputs and API response types live in `types/`.

### Example

```typescript
// ports/inboxed-api.ts
export class InboxedApi {
  constructor(private baseUrl: string, private apiKey: string) {}

  async getMessages(limit?: number): Promise<Message[]> { ... }
  async getMessage(id: string): Promise<Message> { ... }
  async searchMessages(query: string): Promise<Message[]> { ... }
}

// tools/list-messages.ts
import type { InboxedApi } from '../ports/inboxed-api';

export const toolDefinition = {
  name: 'list_messages',
  description: 'List recent emails in Inboxed',
  inputSchema: { type: 'object', properties: { limit: { type: 'number' } } }
};

export async function execute(
  input: { limit?: number },
  api: InboxedApi
): Promise<{ messages: Message[] }> {
  const messages = await api.getMessages(input.limit);
  return { messages };
}

// server.ts
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { InboxedApi } from './ports/inboxed-api';
import * as listMessages from './tools/list-messages';
// ... other tools

export function createServer(api: InboxedApi): McpServer {
  const server = new McpServer({ name: 'inboxed-mcp', version: '0.0.1' });

  server.tool(
    listMessages.toolDefinition.name,
    listMessages.toolDefinition.description,
    listMessages.toolDefinition.inputSchema,
    (input) => listMessages.execute(input, api)
  );

  return server;
}
```

## Consequences

### Easier

- **Adding tools** — create a file, export definition + execute, register in server.ts
- **Testing** — mock the port, test the tool function in isolation
- **Swapping the API** — change one file (`inboxed-api.ts`) if the API evolves
- **Reading the code** — `tools/` directory is the table of contents for MCP capabilities
- **LLM navigation** — predictable structure, each tool is self-contained

### Harder

- **More files than "everything in index.ts"** — but this is a feature, not a bug
- **Port abstraction** — adds indirection for HTTP calls. Minimal overhead for clear boundaries.

### Mitigations

- The MCP server has ~7 tools. This architecture handles that without over-engineering.
- If the server stays simple, the overhead is negligible. If it grows, the pattern scales.
