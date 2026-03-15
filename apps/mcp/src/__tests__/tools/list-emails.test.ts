import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/list-emails.js";
import type { InboxedApi } from "../../ports/inboxed-api.js";

function createMockApi(overrides: Partial<InboxedApi> = {}): InboxedApi {
  return {
    getStatus: vi.fn(),
    listInboxes: vi.fn(),
    findInboxByAddress: vi.fn().mockResolvedValue({
      id: "inbox-1",
      address: "test@mail.inboxed.dev",
      email_count: 5,
      last_email_at: "2026-03-15T10:00:00Z",
      created_at: "2026-03-14T10:00:00Z",
    }),
    deleteInbox: vi.fn(),
    listEmails: vi.fn().mockResolvedValue({
      data: [
        {
          id: "email-1",
          inbox_id: "inbox-1",
          inbox_address: "test@mail.inboxed.dev",
          from: "noreply@app.com",
          subject: "Welcome",
          preview: "Welcome to our app...",
          received_at: "2026-03-15T10:00:00Z",
        },
      ],
      meta: { total_count: 1, next_cursor: null },
    }),
    getEmail: vi.fn(),
    waitForEmail: vi.fn(),
    searchEmails: vi.fn(),
    ...overrides,
  } as unknown as InboxedApi;
}

describe("list_emails", () => {
  it("returns email summaries for a valid inbox", async () => {
    const api = createMockApi();
    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);

    expect(result.isError).toBeUndefined();
    const data = JSON.parse(result.content[0].text);
    expect(data.emails).toHaveLength(1);
    expect(data.emails[0].subject).toBe("Welcome");
    expect(data.total_count).toBe(1);
  });

  it("returns error for unknown inbox", async () => {
    const api = createMockApi({
      findInboxByAddress: vi.fn().mockResolvedValue(null),
    });
    const result = await execute({ inbox: "unknown@mail.inboxed.dev" }, api);

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Inbox not found");
  });

  it("passes limit to API", async () => {
    const api = createMockApi();
    await execute({ inbox: "test@mail.inboxed.dev", limit: 5 }, api);

    expect(api.listEmails).toHaveBeenCalledWith("inbox-1", 5);
  });

  it("defaults limit to 10", async () => {
    const api = createMockApi();
    await execute({ inbox: "test@mail.inboxed.dev" }, api);

    expect(api.listEmails).toHaveBeenCalledWith("inbox-1", 10);
  });

  it("maps API errors via mapApiError", async () => {
    const api = createMockApi({
      findInboxByAddress: vi.fn().mockRejectedValue(new TypeError("fetch failed")),
    });
    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Cannot reach Inboxed API");
  });
});
