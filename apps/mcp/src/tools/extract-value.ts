import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolError, toolSuccess } from "../helpers/errors.js";
import { extractLabeledValue } from "../helpers/extract.js";

export const definition = {
  name: "extract_value",
  description:
    "Extract a labeled value from the latest email in an inbox. Useful for temporary passwords, generated usernames, reference numbers, order IDs, tracking numbers, or any value that appears after a label in the email body. Example: for an email containing 'Temporary password: xK9#mP2!', use label 'password' to extract 'xK9#mP2!'.",
  inputSchema: {
    inbox: z.string().describe("Email address of the inbox"),
    label: z
      .string()
      .describe(
        'Label to search for (e.g., "password", "username", "reference")'
      ),
    pattern: z
      .string()
      .optional()
      .describe(
        "Regex override for the value part (default: captures non-whitespace after label)"
      ),
  },
};

interface Input {
  inbox: string;
  label: string;
  pattern?: string;
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

    const res = await api.listEmails(inbox.id, 1);
    if (res.items.length === 0) {
      return toolError(`No emails in inbox: ${input.inbox}`);
    }

    const emailSummary = res.items[0];
    const email = await api.getEmail(emailSummary.id);
    const value = extractLabeledValue(
      email.body_text,
      email.body_html,
      input.label,
      input.pattern
    );

    if (!value) {
      return toolSuccess({
        value: null,
        message: `No value found for label '${input.label}' in the latest email (subject: '${email.subject}').`,
        label: input.label,
        email_id: email.id,
        email_subject: email.subject,
      });
    }

    return toolSuccess({
      value,
      label: input.label,
      email_id: email.id,
      email_subject: email.subject,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
