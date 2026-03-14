import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new McpServer({
  name: "inboxed-mcp",
  version: "0.0.1",
});

// Tools will be registered in future specs

const transport = new StdioServerTransport();
await server.connect(transport);
