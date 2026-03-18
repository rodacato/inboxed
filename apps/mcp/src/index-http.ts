import { createServer as createHttpServer } from "node:http";
import type { IncomingMessage, ServerResponse } from "node:http";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { InboxedApi } from "./ports/inboxed-api.js";
import { createServer } from "./server.js";

const apiUrl = process.env.INBOXED_API_URL || "http://localhost:3000";
const defaultApiKey = process.env.INBOXED_API_KEY || process.env.INBOXED_MCP_KEY || "";
const port = parseInt(process.env.PORT || "3001", 10);
const allowedOrigins = (process.env.CORS_ORIGINS || "*").split(",").map((o) => o.trim());

function setCorsHeaders(req: IncomingMessage, res: ServerResponse): void {
  const origin = req.headers.origin || "*";
  const allowed = allowedOrigins.includes("*") || allowedOrigins.includes(origin);
  if (allowed) {
    res.setHeader("Access-Control-Allow-Origin", origin);
  }
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.setHeader("Access-Control-Max-Age", "86400");
}

/**
 * Extract the API key from the request. Clients can pass their own key
 * via the Authorization header (passthrough auth). Falls back to the
 * server-level INBOXED_API_KEY env var.
 */
function resolveApiKey(req: IncomingMessage): string {
  const auth = req.headers.authorization;
  if (auth && auth.startsWith("Bearer ")) {
    return auth.slice(7);
  }
  return defaultApiKey;
}

const httpServer = createHttpServer(async (req, res) => {
  const url = new URL(req.url ?? "/", `http://${req.headers.host}`);
  setCorsHeaders(req, res);

  // CORS preflight
  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  // Health check
  if (url.pathname === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok" }));
    return;
  }

  // MCP endpoint
  if (url.pathname === "/mcp") {
    if (req.method === "POST") {
      const apiKey = resolveApiKey(req);
      if (!apiKey) {
        res.writeHead(401, { "Content-Type": "application/json" });
        res.end(
          JSON.stringify({
            jsonrpc: "2.0",
            error: { code: -32000, message: "Authorization required. Pass a Bearer token or set INBOXED_API_KEY." },
            id: null,
          })
        );
        return;
      }

      const api = new InboxedApi(apiUrl, apiKey);
      const server = createServer(api);
      try {
        const transport = new StreamableHTTPServerTransport({
          sessionIdGenerator: undefined,
        });
        await server.connect(transport);

        // Parse body
        const chunks: Buffer[] = [];
        for await (const chunk of req) {
          chunks.push(chunk as Buffer);
        }
        const body = JSON.parse(Buffer.concat(chunks).toString());

        await transport.handleRequest(req, res, body);

        res.on("close", () => {
          transport.close();
          server.close();
        });
      } catch (error) {
        console.error("Error handling MCP request:", error);
        if (!res.headersSent) {
          res.writeHead(500, { "Content-Type": "application/json" });
          res.end(
            JSON.stringify({
              jsonrpc: "2.0",
              error: { code: -32603, message: "Internal server error" },
              id: null,
            })
          );
        }
      }
      return;
    }

    // GET and DELETE not supported in stateless mode
    res.writeHead(405, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        jsonrpc: "2.0",
        error: { code: -32000, message: "Method not allowed." },
        id: null,
      })
    );
    return;
  }

  // 404 for everything else
  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Not found" }));
});

httpServer.listen(port, () => {
  console.log(`Inboxed MCP HTTP server listening on port ${port}`);
});

process.on("SIGINT", () => {
  console.log("Shutting down...");
  httpServer.close();
  process.exit(0);
});
