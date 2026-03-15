import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "list_emails",
  description:
    "List recent emails in an inbox. Returns email summaries sorted by newest first.",
  inputSchema: {
    inbox: z
      .string()
      .describe('Email address of the inbox (e.g., "test@mail.inboxed.dev")'),
    limit: z
      .number()
      .min(1)
      .max(100)
      .optional()
      .describe("Max emails to return (1-100, default: 10)"),
  },
};

interface Input {
  inbox: string;
  limit?: number;
}

export async function execute(
  input: Input,
  api: InboxedApi
): Promise<ToolResult> {
  try {
    const inbox = await api.findInboxByAddress(input.inbox);
    if (!inbox) {
      return toolError(`Inbox not found: ${input.inbox}`);
    }

    const limit = input.limit ?? 10;
    const res = await api.listEmails(inbox.id, limit);

    return toolSuccess({
      emails: res.data.map((e) => ({
        id: e.id,
        from: e.from,
        subject: e.subject,
        preview: e.preview,
        received_at: e.received_at,
      })),
      total_count: res.meta.total_count,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
