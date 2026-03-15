import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolError, toolSuccess } from "../helpers/errors.js";
import { extractCode } from "../helpers/extract.js";

export const definition = {
  name: "extract_code",
  description:
    'Extract a verification code, authentication code, or OTP from the latest email in an inbox. Looks for 4-8 digit codes by default, or matches a custom pattern. Works with numeric codes (482910), alphanumeric codes (AX8-KM2P), and any pattern you specify.',
  inputSchema: {
    inbox: z.string().describe("Email address of the inbox"),
    pattern: z
      .string()
      .optional()
      .describe('Regex pattern (default: "\\b\\d{4,8}\\b")'),
  },
};

interface Input {
  inbox: string;
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
    if (res.data.length === 0) {
      return toolError(`No emails in inbox: ${input.inbox}`);
    }

    const emailSummary = res.data[0];
    const email = await api.getEmail(emailSummary.id);
    const code = extractCode(email.body_text, email.body_html, input.pattern);

    if (!code) {
      return toolSuccess({
        code: null,
        message: `No verification code found in the latest email (subject: '${email.subject}').`,
        email_id: email.id,
        email_subject: email.subject,
      });
    }

    return toolSuccess({
      code,
      email_id: email.id,
      email_subject: email.subject,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
