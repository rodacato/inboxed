import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "create_endpoint",
  description:
    "Create an HTTP endpoint to catch webhook requests, form submissions, or heartbeat pings",
  inputSchema: {
    endpoint_type: z
      .enum(["webhook", "form", "heartbeat"])
      .optional()
      .describe("Type of endpoint (default: webhook)"),
    label: z.string().optional().describe("Human-readable label"),
    expected_interval_seconds: z
      .number()
      .optional()
      .describe(
        "For heartbeat type: expected ping interval in seconds (e.g., 300 for 5 minutes)"
      ),
  },
};

interface Input {
  endpoint_type?: "webhook" | "form" | "heartbeat";
  label?: string;
  expected_interval_seconds?: number;
}

export async function execute(
  input: Input,
  api: InboxedApi
): Promise<ToolResult> {
  try {
    const ep = await api.createEndpoint({
      endpoint_type: input.endpoint_type ?? "webhook",
      label: input.label,
      expected_interval_seconds: input.expected_interval_seconds,
    });

    return toolSuccess({
      token: ep.token,
      url: ep.url,
      endpoint_type: ep.endpoint_type,
      label: ep.label,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
