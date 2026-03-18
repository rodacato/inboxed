import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "get_endpoint",
  description:
    "Get details of an HTTP catcher endpoint by its token, including request count and heartbeat status.",
  inputSchema: {
    endpoint_token: z.string().describe("Endpoint token (e.g., wh_abc123)"),
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
    const ep = await api.getEndpoint(input.endpoint_token);

    return toolSuccess({
      token: ep.token,
      label: ep.label,
      endpoint_type: ep.endpoint_type,
      url: ep.url,
      request_count: ep.request_count,
      heartbeat_status: ep.heartbeat_status,
      last_ping_at: ep.last_ping_at,
      expected_interval_seconds: ep.expected_interval_seconds,
      created_at: ep.created_at,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
