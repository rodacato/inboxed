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

const tools = [
  listEmails,
  getEmail,
  waitForEmail,
  extractCode,
  extractLink,
  extractValue,
  searchEmails,
  deleteInbox,
];

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
      (input: Record<string, unknown>) => tool.execute(input as never, api)
    );
  }

  return server;
}
