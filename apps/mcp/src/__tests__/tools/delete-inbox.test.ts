import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/delete-inbox.js";
import type { InboxedApi } from "../../ports/inboxed-api.js";

describe("delete_inbox", () => {
  it("deletes inbox and returns confirmation", async () => {
    const api = {
      findInboxByAddress: vi.fn().mockResolvedValue({
        id: "inbox-1",
        address: "test@mail.inboxed.dev",
        email_count: 5,
      }),
      deleteInbox: vi.fn().mockResolvedValue(undefined),
    } as unknown as InboxedApi;

    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);

    const data = JSON.parse(result.content[0].text);
    expect(data.deleted).toBe(true);
    expect(data.inbox).toBe("test@mail.inboxed.dev");
    expect(data.email_count).toBe(5);
    expect(api.deleteInbox).toHaveBeenCalledWith("inbox-1");
  });

  it("returns error for unknown inbox", async () => {
    const api = {
      findInboxByAddress: vi.fn().mockResolvedValue(null),
    } as unknown as InboxedApi;

    const result = await execute({ inbox: "unknown@mail.inboxed.dev" }, api);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Inbox not found");
  });

  it("maps API errors via mapApiError", async () => {
    const api = {
      findInboxByAddress: vi.fn().mockResolvedValue({
        id: "inbox-1",
        address: "test@mail.inboxed.dev",
        email_count: 3,
      }),
      deleteInbox: vi.fn().mockRejectedValue(new TypeError("fetch failed")),
    } as unknown as InboxedApi;

    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Cannot reach Inboxed API");
  });
});
