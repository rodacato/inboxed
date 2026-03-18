import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolError, toolSuccess } from "../helpers/errors.js";
import { extractUrls } from "../helpers/extract.js";

export const definition = {
  name: "extract_link",
  description:
    "Extract a URL from the latest email in an inbox. Useful for verification links, magic links, and password reset URLs. Optionally filter by a pattern.",
  inputSchema: {
    inbox: z.string().describe("Email address of the inbox"),
    link_pattern: z
      .string()
      .optional()
      .describe('Regex pattern to match URL (e.g., "verify|confirm|reset")'),
  },
};

interface Input {
  inbox: string;
  link_pattern?: string;
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
    let urls = extractUrls(email.body_text, email.body_html);

    if (input.link_pattern) {
      const pattern = new RegExp(input.link_pattern, "i");
      urls = urls.filter((url) => pattern.test(url));
    }

    if (urls.length === 0) {
      return toolSuccess({
        url: null,
        message: `No matching link found in the latest email (subject: '${email.subject}').`,
        email_id: email.id,
        email_subject: email.subject,
      });
    }

    return toolSuccess({
      url: urls[0],
      email_id: email.id,
      email_subject: email.subject,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
