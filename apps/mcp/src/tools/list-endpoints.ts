import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "list_endpoints",
  description:
    "List HTTP catcher endpoints in the project. Optionally filter by type (webhook, form, heartbeat).",
  inputSchema: {
    type: z
      .enum(["webhook", "form", "heartbeat"])
      .optional()
      .describe("Filter by endpoint type"),
    limit: z
      .number()
      .min(1)
      .max(100)
      .optional()
      .describe("Max endpoints to return (1-100, default: 20)"),
  },
};

interface Input {
  type?: "webhook" | "form" | "heartbeat";
  limit?: number;
}

export async function execute(
  input: Input,
  api: InboxedApi
): Promise<ToolResult> {
  try {
    const res = await api.listEndpoints({
      type: input.type,
      limit: input.limit,
    });

    return toolSuccess({
      endpoints: res.items.map((ep) => ({
        token: ep.token,
        label: ep.label,
        endpoint_type: ep.endpoint_type,
        url: ep.url,
        request_count: ep.request_count,
        heartbeat_status: ep.heartbeat_status,
        created_at: ep.created_at,
      })),
      total_count: res.pagination.total_count,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
