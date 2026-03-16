import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "wait_for_request",
  description:
    "Wait for an HTTP request to arrive at an endpoint (long-poll, up to 30s). Use this after pointing a webhook or form at the endpoint URL.",
  inputSchema: {
    endpoint_token: z.string().describe("Endpoint token"),
    method: z
      .string()
      .optional()
      .describe("Filter by HTTP method (e.g., POST)"),
    timeout_seconds: z
      .number()
      .min(1)
      .max(60)
      .optional()
      .describe("Max seconds to wait (1-60, default: 30)"),
  },
};

interface Input {
  endpoint_token: string;
  method?: string;
  timeout_seconds?: number;
}

export async function execute(
  input: Input,
  api: InboxedApi
): Promise<ToolResult> {
  try {
    const timeout = input.timeout_seconds ?? 30;
    const request = await api.waitForRequest(input.endpoint_token, {
      method: input.method,
      timeout,
    });

    if (!request) {
      return toolSuccess({
        found: false,
        message: `No matching request arrived within ${timeout} seconds.`,
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
        received_at: request.received_at,
      },
    });
  } catch (error) {
    return mapApiError(error);
  }
}
