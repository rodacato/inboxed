import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { InboxedApi } from "./ports/inboxed-api.js";
import { createServer } from "./server.js";

const apiUrl = process.env.INBOXED_API_URL || "http://localhost:3000";
const apiKey = process.env.INBOXED_API_KEY || process.env.INBOXED_MCP_KEY || "";

const api = new InboxedApi(apiUrl, apiKey);
const server = createServer(api);

const transport = new StdioServerTransport();
await server.connect(transport);
