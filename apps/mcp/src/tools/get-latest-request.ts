import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "get_latest_request",
  description:
    "Get the most recent HTTP request captured by an endpoint",
  inputSchema: {
    endpoint_token: z.string().describe("Endpoint token"),
    method: z
      .string()
      .optional()
      .describe("Filter by HTTP method (e.g., POST)"),
  },
};

interface Input {
  endpoint_token: string;
  method?: string;
}

export async function execute(
  input: Input,
  api: InboxedApi
): Promise<ToolResult> {
  try {
    const request = await api.getLatestRequest(
      input.endpoint_token,
      input.method
    );

    if (!request) {
      return toolSuccess({
        found: false,
        message: "No requests captured yet.",
      });
    }

    return toolSuccess({
      found: true,
      request: {
        id: request.id,
        method: request.method,
        path: request.path,
        headers: request.headers,
        body: request.body,
        content_type: request.content_type,
        ip_address: request.ip_address,
        size_bytes: request.size_bytes,
        received_at: request.received_at,
      },
    });
  } catch (error) {
    return mapApiError(error);
  }
}
