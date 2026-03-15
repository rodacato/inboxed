import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "wait_for_email",
  description:
    "Wait for a new email to arrive in an inbox. Blocks until a matching email is received or timeout expires. Use this after triggering an action that sends an email (signup, password reset, etc.).",
  inputSchema: {
    inbox: z.string().describe("Email address of the inbox"),
    subject_pattern: z
      .string()
      .optional()
      .describe("Regex pattern to match subject"),
    timeout_seconds: z
      .number()
      .min(1)
      .max(60)
      .optional()
      .describe("Max wait time (1-60, default: 30)"),
  },
};

interface Input {
  inbox: string;
  subject_pattern?: string;
  timeout_seconds?: number;
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

    const timeout = input.timeout_seconds ?? 30;
    const email = await api.waitForEmail(
      inbox.id,
      input.subject_pattern,
      timeout
    );

    if (!email) {
      // Timeout is NOT an error per ADR-014
      return toolSuccess({
        found: false,
        message: `No matching email arrived within ${timeout} seconds.`,
      });
    }

    return toolSuccess({
      found: true,
      email: {
        id: email.id,
        from: email.from,
        subject: email.subject,
        preview: email.preview,
        received_at: email.received_at,
      },
    });
  } catch (error) {
    return mapApiError(error);
  }
}
