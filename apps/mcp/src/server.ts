import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { InboxedApi } from "./ports/inboxed-api.js";

export function createServer(_api: InboxedApi): McpServer {
  const server = new McpServer({
    name: "inboxed-mcp",
    version: "0.0.1",
  });

  // Tools will be registered here as they are implemented.
  // Each tool file in src/tools/ exports a toolDefinition and execute function.
  //
  // Example:
  //   import * as listMessages from "./tools/list-messages.js";
  //   server.tool(
  //     listMessages.toolDefinition.name,
  //     listMessages.toolDefinition.inputSchema,
  //     (input) => listMessages.execute(input, api)
  //   );

  return server;
}
