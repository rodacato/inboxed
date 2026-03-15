import type { ToolResult } from "../types/index.js";

export class ApiError extends Error {
  constructor(
    public status: number,
    public statusText: string,
    public url: string
  ) {
    super(`Inboxed API error: ${status} ${statusText}`);
    this.name = "ApiError";
  }
}

export function toolSuccess(data: unknown): ToolResult {
  return {
    content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
  };
}

export function toolError(message: string): ToolResult {
  return {
    content: [{ type: "text", text: message }],
    isError: true,
  };
}

export function mapApiError(error: unknown): ToolResult {
  if (error instanceof ApiError) {
    switch (error.status) {
      case 401:
      case 403:
        return toolError("Authentication failed. Check INBOXED_API_KEY.");
      case 404:
        return toolError(`Not found: ${error.url}`);
      case 422:
        return toolError(`Invalid input: ${error.statusText}`);
      case 429:
        return toolError("Rate limited. Try again in a few seconds.");
      default:
        return toolError(
          `Inboxed API error (${error.status}). The server may be temporarily unavailable.`
        );
    }
  }

  if (
    error instanceof TypeError &&
    error.message.includes("fetch")
  ) {
    return toolError(
      "Cannot reach Inboxed API. Check INBOXED_API_URL and ensure the server is running."
    );
  }

  const message =
    error instanceof Error ? error.message : "Unknown error occurred.";
  return toolError(message);
}
