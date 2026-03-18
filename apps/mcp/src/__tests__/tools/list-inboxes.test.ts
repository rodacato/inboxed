import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/list-inboxes.js";
import type { InboxedApi } from "../../ports/inboxed-api.js";

describe("list_inboxes", () => {
  it("returns all inboxes", async () => {
    const api = {
      listInboxes: vi.fn().mockResolvedValue({
        items: [
          {
            id: "inbox-1",
            address: "test@mail.inboxed.dev",
            email_count: 5,
            created_at: "2026-03-14T10:00:00Z",
          },
          {
            id: "inbox-2",
            address: "other@mail.inboxed.dev",
            email_count: 0,
            created_at: "2026-03-15T10:00:00Z",
          },
        ],
        pagination: { has_more: false, next_cursor: null, total_count: 2 },
      }),
    } as unknown as InboxedApi;

    const result = await execute({} as never, api);

    expect(result.isError).toBeUndefined();
    const data = JSON.parse(result.content[0].text);
    expect(data.inboxes).toHaveLength(2);
    expect(data.inboxes[0].address).toBe("test@mail.inboxed.dev");
    expect(data.total_count).toBe(2);
  });

  it("maps API errors", async () => {
    const api = {
      listInboxes: vi.fn().mockRejectedValue(new TypeError("fetch failed")),
    } as unknown as InboxedApi;

    const result = await execute({} as never, api);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Cannot reach Inboxed API");
  });
});
