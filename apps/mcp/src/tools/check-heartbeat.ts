import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "check_heartbeat",
  description:
    "Check the current status of a heartbeat endpoint (healthy, late, down, or pending)",
  inputSchema: {
    endpoint_token: z.string().describe("Endpoint token"),
  },
};

interface Input {
  endpoint_token: string;
}

export async function execute(
  input: Input,
  api: InboxedApi
): Promise<ToolResult> {
  try {
    const res = await api.getEndpoint(input.endpoint_token);
    const ep = res.data;

    if (ep.endpoint_type !== "heartbeat") {
      return toolError(
        `Endpoint is type "${ep.endpoint_type}", not a heartbeat.`
      );
    }

    return toolSuccess({
      status: ep.heartbeat_status,
      label: ep.label,
      last_ping_at: ep.last_ping_at,
      expected_interval_seconds: ep.expected_interval_seconds,
      request_count: ep.request_count,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
