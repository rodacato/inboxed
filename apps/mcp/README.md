# Inboxed MCP Server

MCP (Model Context Protocol) server that allows AI agents to interact with Inboxed programmatically. AI agents can read, search, and extract data from captured test emails without leaving their execution context.

## Tools

| Tool | Description |
|------|-------------|
| `list_emails` | List recent emails in an inbox (newest first) |
| `get_email` | Get full email detail including body and attachments |
| `wait_for_email` | Long-poll until a matching email arrives or timeout expires |
| `extract_code` | Extract verification/auth codes (4-8 digit, or custom pattern) |
| `extract_link` | Extract URLs from email body (with optional pattern filter) |
| `extract_value` | Extract labeled values (passwords, usernames, reference numbers) |
| `search_emails` | Full-text search across all emails in the project |
| `delete_inbox` | Delete an inbox and all its emails |

## Configuration

The server requires two environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `INBOXED_API_URL` | URL of the Inboxed REST API | `http://localhost:3000` |
| `INBOXED_API_KEY` | API key for authentication | (empty) |

## Connecting from Claude Code

Add to your MCP configuration (`.claude/mcp.json` or Claude Code settings):

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

## Connecting from Cursor

Add to `.cursor/mcp.json`:

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

## Development

```bash
npm install        # Install dependencies
npm run build      # Compile TypeScript
npm run check      # Type-check without emitting
npm run dev        # Watch mode
npm run test       # Run tests
```

## Architecture

Follows the **hexagonal light** pattern (ADR-005):

```
src/
├── index.ts           # Entry point (env vars, stdio transport)
├── server.ts          # Tool registration
├── types/index.ts     # Shared TypeScript interfaces
├── ports/
│   └── inboxed-api.ts # HTTP client for REST API
├── helpers/
│   ├── extract.ts     # Code, link, and value extraction
│   └── errors.ts      # Error mapping to MCP results
└── tools/             # One file per MCP tool
```

- **Tools** are pure functions: receive input + API port, return structured output.
- **Ports** encapsulate all HTTP communication.
- **Helpers** provide extraction logic and centralized error mapping.
- **Zero state** — each tool invocation is independent.
