import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "list_requests",
  description:
    "List captured HTTP requests for an endpoint. Returns request summaries sorted by newest first.",
  inputSchema: {
    endpoint_token: z.string().describe("Endpoint token"),
    limit: z
      .number()
      .min(1)
      .max(100)
      .optional()
      .describe("Max requests to return (1-100, default: 10)"),
    method: z
      .string()
      .optional()
      .describe("Filter by HTTP method (e.g., POST)"),
  },
};

interface Input {
  endpoint_token: string;
  limit?: number;
  method?: string;
}

export async function execute(
  input: Input,
  api: InboxedApi
): Promise<ToolResult> {
  try {
    const res = await api.listRequests(input.endpoint_token, {
      limit: input.limit ?? 10,
      method: input.method,
    });

    return toolSuccess({
      requests: res.items.map((r) => ({
        id: r.id,
        method: r.method,
        path: r.path,
        content_type: r.content_type,
        ip_address: r.ip_address,
        size_bytes: r.size_bytes,
        received_at: r.received_at,
      })),
      total_count: res.pagination.total_count,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
