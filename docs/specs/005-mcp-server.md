# 005 — MCP Server

> AI agents can read, search, and extract data from captured emails via the Model Context Protocol.

**Phase:** Phase 4 — MCP Server
**Status:** implemented
**Release:** —
**Depends on:** [003 — REST API](003-rest-api.md)
**ADRs:** [ADR-005 Hexagonal Light](../adrs/005-mcp-hexagonal.md), [ADR-013 Tool Design](../adrs/013-mcp-tool-design.md), [ADR-014 Error Handling](../adrs/014-mcp-error-handling.md)

---

## 1. Objective

Build the MCP server that allows AI agents (Claude Code, Cursor, etc.) to interact with Inboxed programmatically. This is Inboxed's **key differentiator** — no competitor offers native MCP integration for email testing.

An AI agent should be able to:
- List and read emails in any inbox
- Wait for an email to arrive (long-poll)
- Extract verification codes, links, and labeled values without leaving the conversation
- Search across all emails in a project
- Clean up test data

## 2. Current State

The MCP server scaffold exists in `apps/mcp/`:

| File | Status |
|------|--------|
| `package.json` | Complete — MCP SDK v1.27.1, TypeScript 5.9 |
| `tsconfig.json` | Complete — ES2022/Node16 target |
| `Dockerfile` | Complete — multi-stage Alpine build |
| `src/index.ts` | Complete — loads env vars, connects stdio transport |
| `src/server.ts` | Scaffold — `createServer()` with no tools registered |
| `src/ports/inboxed-api.ts` | Scaffold — `InboxedApi` class with `getStatus()` only |
| `src/types/index.ts` | Scaffold — basic `Message` and `ApiStatus` interfaces |
| `src/tools/` | Does not exist yet |

The REST API (spec 003) provides all the endpoints the MCP server needs:
- `GET /api/v1/inboxes` — list inboxes
- `GET /api/v1/inboxes/:id/emails` — list emails in inbox
- `GET /api/v1/emails/:id` — get email detail
- `GET /api/v1/search` — full-text search
- `POST /api/v1/emails/wait` — long-poll for new email
- `DELETE /api/v1/inboxes/:id` — delete inbox

## 3. What This Spec Delivers

### 3.1 Eight MCP Tools

| Tool | Description | REST API Mapping |
|------|-------------|-----------------|
| `list_emails` | List recent emails in an inbox | `GET /inboxes` → resolve address → `GET /inboxes/:id/emails` |
| `get_email` | Get full email detail by ID | `GET /emails/:id` |
| `wait_for_email` | Long-poll until a matching email arrives | `POST /emails/wait` |
| `extract_code` | Extract verification/auth code from latest email | `GET /inboxes/:id/emails` → regex on body |
| `extract_link` | Extract a URL from the latest email | `GET /inboxes/:id/emails` → regex/parse on body |
| `extract_value` | Extract any labeled value (password, username, etc.) | `GET /inboxes/:id/emails` → label-based search on body |
| `search_emails` | Full-text search across project emails | `GET /search` |
| `delete_inbox` | Delete an inbox and all its emails | `DELETE /inboxes/:id` |

### 3.2 Expanded API Client

The `InboxedApi` port gets full method coverage for all REST API endpoints the tools consume.

### 3.3 Shared Type Definitions

Complete TypeScript interfaces matching the API response schemas from spec 003.

### 3.4 Error Handling

Centralized error mapping per ADR-014 — structured `isError` responses with agent-readable messages.

---

## 4. Tool Specifications

### 4.1 `list_emails`

```typescript
name: "list_emails"
description: "List recent emails in an inbox. Returns email summaries sorted by newest first."

inputSchema: {
  inbox: string       // Required. Email address (e.g., "test@mail.inboxed.dev")
  limit: number       // Optional. Max emails to return (1-100, default: 10)
}

// Output: array of email summaries
{
  emails: [
    {
      id: string
      from: string
      subject: string
      preview: string        // First ~200 chars of body text
      received_at: string    // ISO 8601
    }
  ],
  total_count: number
}
```

**Behavior:**
1. Resolve `inbox` address to inbox ID via `GET /api/v1/inboxes?address={inbox}`
2. Fetch emails via `GET /api/v1/inboxes/:id/emails?limit={limit}`
3. Return simplified summaries (not full bodies — keep token usage low)

### 4.2 `get_email`

```typescript
name: "get_email"
description: "Get full email detail including body content. Use list_emails first to find the email ID."

inputSchema: {
  email_id: string    // Required. Email UUID
}

// Output: full email detail
{
  id: string
  from: string
  to: string[]
  cc: string[]
  subject: string
  body_text: string | null
  body_html: string | null
  received_at: string
  attachments: [
    { id: string, filename: string, content_type: string, size_bytes: number }
  ]
}
```

**Behavior:**
1. Fetch email via `GET /api/v1/emails/:id`
2. Return full detail including both body formats
3. Include attachment metadata (not binary content)

### 4.3 `wait_for_email`

```typescript
name: "wait_for_email"
description: "Wait for a new email to arrive in an inbox. Blocks until a matching email is received or timeout expires. Use this after triggering an action that sends an email (signup, password reset, etc.)."

inputSchema: {
  inbox: string              // Required. Email address
  subject_pattern: string    // Optional. Regex pattern to match subject
  timeout_seconds: number    // Optional. Max wait time (1-60, default: 30)
}

// Output on match:
{
  found: true
  email: { id, from, subject, preview, received_at }
}

// Output on timeout (NOT an error):
{
  found: false
  message: "No matching email arrived within 30 seconds."
}
```

**Behavior:**
1. Resolve `inbox` address to inbox ID
2. Call `POST /api/v1/emails/wait` with `inbox_id`, `subject_pattern`, and `timeout`
3. If the API returns an email, return `found: true` with summary
4. If the API returns 408 (timeout), return `found: false` with message — this is **not** an `isError` (per ADR-014)
5. Agent can call again to continue waiting

### 4.4 `extract_code`

```typescript
name: "extract_code"
description: "Extract a verification code, authentication code, or OTP from the latest email in an inbox. Looks for 4-8 digit codes by default, or matches a custom pattern. Works with numeric codes (482910), alphanumeric codes (AX8-KM2P), and any pattern you specify."

inputSchema: {
  inbox: string        // Required. Email address
  pattern: string      // Optional. Regex pattern (default: "\\b\\d{4,8}\\b")
}

// Output on match:
{
  code: string              // The extracted code
  email_id: string          // Source email ID
  email_subject: string     // Source email subject
}

// Output when no code found:
{
  code: null
  message: "No verification code found in the latest email (subject: 'Welcome to App')."
  email_id: string
  email_subject: string
}
```

**Behavior:**
1. Resolve inbox address → inbox ID
2. Fetch the latest email via `GET /api/v1/inboxes/:id/emails?limit=1`
3. Search `body_text` first, fall back to stripped `body_html`
4. Apply regex pattern, return last match (codes typically appear after context text like "Your code is:")
5. If no match, return `code: null` with context (not `isError` — the email exists, it just doesn't contain a code)

### 4.5 `extract_link`

```typescript
name: "extract_link"
description: "Extract a URL from the latest email in an inbox. Useful for verification links, magic links, and password reset URLs. Optionally filter by a pattern."

inputSchema: {
  inbox: string            // Required. Email address
  link_pattern: string     // Optional. Regex pattern to match URL (e.g., "verify|confirm|reset")
}

// Output on match:
{
  url: string               // The extracted URL
  email_id: string
  email_subject: string
}

// Output when no link found:
{
  url: null
  message: "No matching link found in the latest email (subject: 'Welcome')."
  email_id: string
  email_subject: string
}
```

**Behavior:**
1. Resolve inbox address → inbox ID
2. Fetch the latest email via `GET /api/v1/inboxes/:id/emails?limit=1` then `GET /api/v1/emails/:id` for full body
3. Extract URLs from `body_text` using URL regex (`https?://[^\s<>"]+`)
4. If `body_text` is null, parse `href` attributes from `body_html`
5. If `link_pattern` is provided, filter URLs by pattern match
6. Return first matching URL

### 4.6 `extract_value`

```typescript
name: "extract_value"
description: "Extract a labeled value from the latest email in an inbox. Useful for temporary passwords, generated usernames, reference numbers, order IDs, tracking numbers, or any value that appears after a label in the email body. Example: for an email containing 'Temporary password: xK9#mP2!', use label 'password' to extract 'xK9#mP2!'."

inputSchema: {
  inbox: string        // Required. Email address
  label: string        // Required. Label to search for (e.g., "password", "username", "reference")
  pattern: string      // Optional. Regex override for the value part (default: captures non-whitespace after label)
}

// Output on match:
{
  value: string             // The extracted value
  label: string             // The label that was searched
  email_id: string          // Source email ID
  email_subject: string     // Source email subject
}

// Output when no value found:
{
  value: null
  message: "No value found for label 'password' in the latest email (subject: 'Welcome')."
  label: string
  email_id: string
  email_subject: string
}
```

**Behavior:**
1. Resolve inbox address → inbox ID
2. Fetch the latest email via `GET /api/v1/inboxes/:id/emails?limit=1` then `GET /api/v1/emails/:id` for full body
3. Search `body_text` first, fall back to stripped `body_html`
4. Build regex from label: `{label}[:\s]+(\S+)` (case-insensitive). Common patterns matched:
   - `Password: xK9#mP2!`
   - `Username: user_8a7c3f`
   - `Reference #: ORD-99281`
   - `Tracking number: 1Z999AA10123456784`
5. If `pattern` is provided, use it as the value capture regex instead of `\S+`
6. Return first match

### 4.7 `search_emails`

```typescript
name: "search_emails"
description: "Full-text search across all emails in the project. Searches subject and body content."

inputSchema: {
  query: string        // Required. Search query
  limit: number        // Optional. Max results (1-50, default: 10)
}

// Output:
{
  emails: [
    { id, inbox_address, from, subject, preview, received_at, relevance: number }
  ],
  total_count: number
}
```

**Behavior:**
1. Call `GET /api/v1/search?q={query}&limit={limit}`
2. Return results with relevance scores

### 4.8 `delete_inbox`

```typescript
name: "delete_inbox"
description: "Delete an inbox and all its emails. Use this to clean up test data after a test run."

inputSchema: {
  inbox: string        // Required. Email address
}

// Output:
{
  deleted: true
  inbox: string
  email_count: number    // How many emails were deleted
}
```

**Behavior:**
1. Resolve inbox address → inbox ID
2. Call `DELETE /api/v1/inboxes/:id`
3. Return confirmation with count of deleted emails

---

## 5. Technical Decisions

### 5.1 Decision: Inbox Resolution by Address

- **Options considered:** (A) Accept inbox UUID, (B) Accept email address and resolve, (C) Accept both
- **Chosen:** B — accept email address only
- **Why:** AI agents know the email address they configured in the app under test (e.g., `test-user@mail.inboxed.dev`). They don't know the internal UUID. Requiring UUIDs adds friction and an extra tool call.
- **Trade-offs:** Extra API call per tool invocation to resolve address → ID. Mitigated by the inbox list being small and fast.

### 5.2 Decision: Extraction in MCP Server

See [ADR-013](../adrs/013-mcp-tool-design.md). Extraction logic (codes, links, labeled values) lives in the MCP server as pure TypeScript functions, not in the Rails API. Three extraction tools cover all common patterns:
- `extract_code` — numeric/alphanumeric verification codes
- `extract_link` — URLs
- `extract_value` — any labeled value (passwords, usernames, reference numbers)

### 5.3 Decision: Structured Error Responses

See [ADR-014](../adrs/014-mcp-error-handling.md). All errors use MCP SDK's `isError: true` with agent-readable messages. Timeouts on `wait_for_email` are not errors.

### 5.4 Decision: Stdio Transport Only

- **Options considered:** (A) Stdio only, (B) Stdio + HTTP/SSE, (C) HTTP/SSE only
- **Chosen:** A — stdio only
- **Why:** Claude Code, Cursor, and all major MCP clients use stdio transport. HTTP/SSE adds complexity (CORS, port management, auth) with no current consumer. Add it when needed.
- **Trade-offs:** Can't be used as a remote MCP server. Acceptable for a self-hosted tool.

---

## 6. Implementation Plan

### Step 1: Type Definitions

Expand `src/types/index.ts` with complete interfaces matching API response schemas:

```typescript
// Types matching REST API responses (spec 003 serializers)
export interface Inbox {
  id: string;
  address: string;
  email_count: number;
  last_email_at: string | null;
  created_at: string;
}

export interface EmailSummary {
  id: string;
  inbox_id: string;
  inbox_address: string;
  from: string;
  subject: string;
  preview: string;
  received_at: string;
}

export interface EmailDetail extends EmailSummary {
  to: string[];
  cc: string[];
  body_text: string | null;
  body_html: string | null;
  source_type: string;
  raw_headers: Record<string, string>;
  expires_at: string | null;
  attachments: AttachmentMeta[];
}

export interface AttachmentMeta {
  id: string;
  filename: string;
  content_type: string;
  size_bytes: number;
  inline: boolean;
}

export interface SearchResult extends EmailSummary {
  relevance: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: {
    total_count: number;
    next_cursor: string | null;
  };
}

// MCP tool result helpers
export interface ToolSuccess {
  content: Array<{ type: "text"; text: string }>;
  isError?: false;
}

export interface ToolError {
  content: Array<{ type: "text"; text: string }>;
  isError: true;
}

export type ToolResult = ToolSuccess | ToolError;
```

### Step 2: Expand the API Client

Rewrite `src/ports/inboxed-api.ts` with full method coverage:

```typescript
export class InboxedApi {
  constructor(private baseUrl: string, private apiKey: string) {}

  // Inbox operations
  async listInboxes(): Promise<PaginatedResponse<Inbox>>
  async findInboxByAddress(address: string): Promise<Inbox | null>
  async deleteInbox(id: string): Promise<void>

  // Email operations
  async listEmails(inboxId: string, limit?: number): Promise<PaginatedResponse<EmailSummary>>
  async getEmail(id: string): Promise<EmailDetail>
  async waitForEmail(inboxId: string, subjectPattern?: string, timeoutSeconds?: number): Promise<EmailSummary | null>

  // Search
  async searchEmails(query: string, limit?: number): Promise<PaginatedResponse<SearchResult>>

  // Status
  async getStatus(): Promise<ApiStatus>
}
```

Key implementation details:
- `findInboxByAddress` calls `GET /api/v1/inboxes?address={address}` and returns the first match or `null`
- `waitForEmail` calls `POST /api/v1/emails/wait` and returns `null` on 408 timeout (not an exception)
- All methods throw `ApiError` (custom class) for non-2xx/non-408 responses

### Step 3: Error Handling Helper

Create `src/helpers/errors.ts`:

```typescript
export class ApiError extends Error {
  constructor(
    public status: number,
    public statusText: string,
    public url: string
  ) {
    super(`Inboxed API error: ${status} ${statusText}`);
  }
}

export function mapApiError(error: unknown): ToolResult {
  if (error instanceof ApiError) {
    // Map HTTP status to agent-readable message
    // See ADR-014 for full mapping table
  }
  if (error instanceof TypeError && error.message.includes("fetch")) {
    // Network error
  }
  // Unknown error
}
```

### Step 4: Extraction Helpers

Create `src/helpers/extract.ts`:

```typescript
/**
 * Extract a verification code from email body text.
 * Default pattern matches 4-8 digit codes. Supports custom regex for
 * alphanumeric codes (e.g., "AX8-KM2P" with pattern "[A-Z0-9]{3}-[A-Z0-9]{4}").
 */
export function extractCode(
  bodyText: string | null,
  bodyHtml: string | null,
  pattern?: string
): string | null {
  const text = bodyText ?? stripHtml(bodyHtml ?? "");
  const regex = new RegExp(pattern ?? "\\b\\d{4,8}\\b", "g");
  const matches = text.match(regex);
  // Return the last match (codes typically appear after context text like "Your code is:")
  return matches ? matches[matches.length - 1] : null;
}

/**
 * Extract URLs from email body.
 * Searches body_text first, falls back to href parsing in body_html.
 */
export function extractUrls(
  bodyText: string | null,
  bodyHtml: string | null
): string[] {
  if (bodyText) {
    const urlRegex = /https?:\/\/[^\s<>")\]]+/g;
    return bodyText.match(urlRegex) ?? [];
  }
  if (bodyHtml) {
    const hrefRegex = /href=["'](https?:\/\/[^"']+)["']/gi;
    const urls: string[] = [];
    let match;
    while ((match = hrefRegex.exec(bodyHtml)) !== null) {
      urls.push(match[1]);
    }
    return urls;
  }
  return [];
}

/**
 * Extract a labeled value from email body text.
 * Searches for patterns like "Password: xK9#mP2!" or "Username: user_8a7c3f".
 * The label match is case-insensitive.
 */
export function extractLabeledValue(
  bodyText: string | null,
  bodyHtml: string | null,
  label: string,
  valuePattern?: string
): string | null {
  const text = bodyText ?? stripHtml(bodyHtml ?? "");
  const valueCapture = valuePattern ?? "\\S+";
  const regex = new RegExp(`${escapeRegex(label)}[:#\\s]\\s*(${valueCapture})`, "i");
  const match = text.match(regex);
  return match ? match[1] : null;
}

/**
 * Escape special regex characters in a string (for label matching).
 */
function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Strip HTML tags to get plain text.
 */
export function stripHtml(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .trim();
}
```

### Step 5: Implement Tools

Create one file per tool in `src/tools/`. Each follows the pattern from ADR-005:

```
src/tools/
├── list-emails.ts
├── get-email.ts
├── wait-for-email.ts
├── extract-code.ts
├── extract-link.ts
├── extract-value.ts
├── search-emails.ts
└── delete-inbox.ts
```

Each tool exports:
```typescript
export const definition = { name, description, inputSchema };
export async function execute(input: Input, api: InboxedApi): Promise<ToolResult>;
```

**Implementation order** (most fundamental first):
1. `list-emails` — core CRUD, tests inbox resolution
2. `get-email` — core CRUD
3. `search-emails` — core CRUD
4. `delete-inbox` — core CRUD
5. `wait-for-email` — long-poll, timeout handling
6. `extract-code` — uses extraction helpers
7. `extract-link` — uses extraction helpers
8. `extract-value` — uses extraction helpers

### Step 6: Wire Tools in server.ts

Update `src/server.ts` to import and register all tools:

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { InboxedApi } from "./ports/inboxed-api.js";
import * as listEmails from "./tools/list-emails.js";
import * as getEmail from "./tools/get-email.js";
import * as waitForEmail from "./tools/wait-for-email.js";
import * as extractCode from "./tools/extract-code.js";
import * as extractLink from "./tools/extract-link.js";
import * as extractValue from "./tools/extract-value.js";
import * as searchEmails from "./tools/search-emails.js";
import * as deleteInbox from "./tools/delete-inbox.js";

const tools = [listEmails, getEmail, waitForEmail, extractCode, extractLink, extractValue, searchEmails, deleteInbox];

export function createServer(api: InboxedApi): McpServer {
  const server = new McpServer({
    name: "inboxed-mcp",
    version: "0.1.0",
  });

  for (const tool of tools) {
    server.tool(
      tool.definition.name,
      tool.definition.description,
      tool.definition.inputSchema,
      (input) => tool.execute(input, api)
    );
  }

  return server;
}
```

### Step 7: Tests

Add Vitest for unit testing. Create tests for:

```
src/__tests__/
├── helpers/
│   ├── extract.test.ts         # OTP and link extraction
│   └── errors.test.ts          # Error mapping
├── tools/
│   ├── list-emails.test.ts     # Mock API, verify tool output
│   ├── get-email.test.ts
│   ├── wait-for-email.test.ts  # Test timeout behavior
│   ├── extract-code.test.ts    # Test with various email formats
│   ├── extract-link.test.ts
│   ├── extract-value.test.ts   # Test label-based extraction
│   ├── search-emails.test.ts
│   └── delete-inbox.test.ts
└── ports/
    └── inboxed-api.test.ts     # Mock fetch, verify HTTP calls
```

**Testing strategy:**
- **Extraction helpers:** Pure function tests with various email body formats (plain text, HTML, mixed)
- **Tools:** Mock `InboxedApi`, verify the tool calls the right methods and formats output correctly
- **API client:** Mock `fetch`, verify correct URLs, headers, and error handling

### Step 8: Update Dockerfile & Docker Compose

1. Verify the existing `apps/mcp/Dockerfile` works with the new code
2. Add the MCP server to `docker-compose.yml` (if not already present)
3. Configure environment variables: `INBOXED_API_URL`, `INBOXED_API_KEY`

### Step 9: Documentation

1. Update `apps/mcp/README.md` with:
   - Available tools and their parameters
   - Configuration (env vars)
   - How to connect from Claude Code / Cursor
2. Add MCP server configuration example:
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

---

## 7. File Structure (Final)

```
apps/mcp/
├── package.json
├── tsconfig.json
├── vitest.config.ts
├── Dockerfile
├── README.md
└── src/
    ├── index.ts                    # Entry point (env vars, stdio transport)
    ├── server.ts                   # Tool registration
    ├── types/
    │   └── index.ts                # All shared interfaces
    ├── ports/
    │   └── inboxed-api.ts          # HTTP client for REST API
    ├── helpers/
    │   ├── extract.ts              # Code, link, and value extraction
    │   └── errors.ts               # Error mapping to MCP results
    ├── tools/
    │   ├── list-emails.ts
    │   ├── get-email.ts
    │   ├── wait-for-email.ts
    │   ├── extract-code.ts
    │   ├── extract-link.ts
    │   ├── extract-value.ts
    │   ├── search-emails.ts
    │   └── delete-inbox.ts
    └── __tests__/
        ├── helpers/
        │   ├── extract.test.ts
        │   └── errors.test.ts
        ├── tools/
        │   ├── list-emails.test.ts
        │   ├── get-email.test.ts
        │   ├── wait-for-email.test.ts
        │   ├── extract-code.test.ts
        │   ├── extract-link.test.ts
        │   ├── extract-value.test.ts
        │   ├── search-emails.test.ts
        │   └── delete-inbox.test.ts
        └── ports/
            └── inboxed-api.test.ts
```

---

## 8. Exit Criteria

- [ ] **EC-001:** All 8 MCP tools are registered and respond to `tools/list` via stdio
- [ ] **EC-002:** `list_emails` returns email summaries for a given inbox address
- [ ] **EC-003:** `get_email` returns full email detail including body and attachment metadata
- [ ] **EC-004:** `wait_for_email` blocks until a matching email arrives, returns it within 2 seconds of delivery
- [ ] **EC-005:** `wait_for_email` returns `found: false` (not an error) when timeout expires
- [ ] **EC-006:** `extract_code` extracts a 6-digit verification code from an email body
- [ ] **EC-007:** `extract_code` works with custom patterns (e.g., `[A-Z0-9]{3}-[A-Z0-9]{4}` for alphanumeric codes)
- [ ] **EC-008:** `extract_link` extracts a verification URL from an HTML email
- [ ] **EC-009:** `extract_value` extracts a temporary password from an email containing "Password: xK9#mP2!"
- [ ] **EC-010:** `extract_value` extracts a username from an email containing "Username: user_8a7c3f"
- [ ] **EC-011:** `search_emails` returns results matching a query string
- [ ] **EC-012:** `delete_inbox` removes an inbox and confirms deletion
- [ ] **EC-013:** Invalid inbox address returns `isError: true` with "Inbox not found" message
- [ ] **EC-014:** Invalid API key returns `isError: true` with "Authentication failed" message
- [ ] **EC-015:** All extraction helpers have unit tests with >90% coverage
- [ ] **EC-016:** All tools have unit tests with mocked API client
- [ ] **EC-017:** `npm run build` succeeds with zero TypeScript errors
- [ ] **EC-018:** Claude Code can connect to the MCP server and invoke `extract_code` on a real email end-to-end

## 9. Open Questions

None — all decisions captured in ADRs 005, 013, and 014.
