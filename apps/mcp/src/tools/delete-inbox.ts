import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "delete_inbox",
  description:
    "Delete an inbox and all its emails. Use this to clean up test data after a test run.",
  inputSchema: {
    inbox: z.string().describe("Email address of the inbox"),
  },
};

interface Input {
  inbox: string;
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

    const emailCount = inbox.email_count;
    await api.deleteInbox(inbox.id);

    return toolSuccess({
      deleted: true,
      inbox: input.inbox,
      email_count: emailCount,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
