import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "extract_json_field",
  description:
    'Extract a value from the JSON body of the latest request using a dot-notation path (e.g., "data.object.id", "items[0].name")',
  inputSchema: {
    endpoint_token: z.string().describe("Endpoint token"),
    json_path: z
      .string()
      .describe(
        'Dot-notation path (e.g., "data.object.id", "items[0].name")'
      ),
  },
};

interface Input {
  endpoint_token: string;
  json_path: string;
}

function getByPath(obj: unknown, path: string): unknown {
  const parts = path.replace(/\[(\d+)\]/g, ".$1").split(".");
  let current: unknown = obj;
  for (const part of parts) {
    if (current == null || typeof current !== "object") return undefined;
    current = (current as Record<string, unknown>)[part];
  }
  return current;
}

export async function execute(
  input: Input,
  api: InboxedApi
): Promise<ToolResult> {
  try {
    const request = await api.getLatestRequest(input.endpoint_token);
    if (!request) {
      return toolError("No requests captured yet.");
    }

    if (!request.body) {
      return toolError("Request has no body.");
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(request.body);
    } catch {
      return toolError("Request body is not valid JSON.");
    }

    const value = getByPath(parsed, input.json_path);
    if (value === undefined) {
      return toolError(
        `Path "${input.json_path}" not found in JSON body.`
      );
    }

    return toolSuccess({
      value,
      path: input.json_path,
      request_id: request.id,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
