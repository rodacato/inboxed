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
import * as createEndpoint from "./tools/create-endpoint.js";
import * as waitForRequest from "./tools/wait-for-request.js";
import * as getLatestRequest from "./tools/get-latest-request.js";
import * as extractJsonField from "./tools/extract-json-field.js";
import * as listRequests from "./tools/list-requests.js";
import * as checkHeartbeat from "./tools/check-heartbeat.js";
import * as deleteEndpoint from "./tools/delete-endpoint.js";
import * as listInboxes from "./tools/list-inboxes.js";
import * as listEndpoints from "./tools/list-endpoints.js";
import * as getEndpoint from "./tools/get-endpoint.js";

const tools = [
  listInboxes,
  listEmails,
  getEmail,
  waitForEmail,
  extractCode,
  extractLink,
  extractValue,
  searchEmails,
  deleteInbox,
  listEndpoints,
  getEndpoint,
  createEndpoint,
  waitForRequest,
  getLatestRequest,
  extractJsonField,
  listRequests,
  checkHeartbeat,
  deleteEndpoint,
];

export function createServer(api: InboxedApi): McpServer {
  const server = new McpServer({
    name: "inboxed-mcp",
    version: "0.2.0",
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
