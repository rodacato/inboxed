import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "delete_endpoint",
  description:
    "Delete an HTTP endpoint and all its captured requests",
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
    await api.deleteEndpoint(input.endpoint_token);
    return toolSuccess({
      deleted: true,
      token: input.endpoint_token,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
