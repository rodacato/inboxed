import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "get_email",
  description:
    "Get full email detail including body content. Use list_emails first to find the email ID.",
  inputSchema: {
    email_id: z.string().describe("Email UUID"),
  },
};

interface Input {
  email_id: string;
}

export async function execute(
  input: Input,
  api: InboxedApi
): Promise<ToolResult> {
  try {
    const email = await api.getEmail(input.email_id);

    return toolSuccess({
      id: email.id,
      from: email.from,
      to: email.to,
      cc: email.cc,
      subject: email.subject,
      body_text: email.body_text,
      body_html: email.body_html,
      received_at: email.received_at,
      attachments: email.attachments.map((a) => ({
        id: a.id,
        filename: a.filename,
        content_type: a.content_type,
        size_bytes: a.size_bytes,
      })),
    });
  } catch (error) {
    return mapApiError(error);
  }
}
