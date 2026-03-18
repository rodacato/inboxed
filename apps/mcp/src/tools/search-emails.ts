import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "search_emails",
  description:
    "Full-text search across all emails in the project. Searches subject and body content.",
  inputSchema: {
    query: z.string().describe("Search query"),
    limit: z
      .number()
      .min(1)
      .max(50)
      .optional()
      .describe("Max results (1-50, default: 10)"),
  },
};

interface Input {
  query: string;
  limit?: number;
}

export async function execute(
  input: Input,
  api: InboxedApi
): Promise<ToolResult> {
  try {
    const limit = input.limit ?? 10;
    const res = await api.searchEmails(input.query, limit);

    return toolSuccess({
      emails: res.items.map((e) => ({
        id: e.id,
        inbox_address: e.inbox_address,
        from: e.from,
        subject: e.subject,
        preview: e.preview,
        received_at: e.received_at,
        relevance: e.relevance,
      })),
      total_count: res.pagination.total_count,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
