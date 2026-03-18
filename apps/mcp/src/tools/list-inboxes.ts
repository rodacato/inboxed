import { z } from "zod";
import type { InboxedApi } from "../ports/inboxed-api.js";
import type { ToolResult } from "../types/index.js";
import { mapApiError, toolSuccess } from "../helpers/errors.js";

export const definition = {
  name: "list_inboxes",
  description:
    "List all inboxes in the project. Returns inbox addresses and email counts.",
  inputSchema: {},
};

type Input = Record<string, never>;

export async function execute(
  _input: Input,
  api: InboxedApi
): Promise<ToolResult> {
  try {
    const res = await api.listInboxes();

    return toolSuccess({
      inboxes: res.items.map((i) => ({
        id: i.id,
        address: i.address,
        email_count: i.email_count,
        created_at: i.created_at,
      })),
      total_count: res.pagination.total_count,
    });
  } catch (error) {
    return mapApiError(error);
  }
}
