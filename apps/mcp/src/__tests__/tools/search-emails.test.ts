import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/search-emails.js";
import type { InboxedApi } from "../../ports/inboxed-api.js";

describe("search_emails", () => {
  it("returns search results", async () => {
    const api = {
      searchEmails: vi.fn().mockResolvedValue({
        data: [
          {
            id: "email-1",
            inbox_id: "inbox-1",
            inbox_address: "test@mail.inboxed.dev",
            from: "noreply@app.com",
            subject: "Password reset",
            preview: "Click here to reset...",
            received_at: "2026-03-15T10:00:00Z",
            relevance: 0.95,
          },
        ],
        meta: { total_count: 1, next_cursor: null },
      }),
    } as unknown as InboxedApi;

    const result = await execute({ query: "password reset" }, api);

    const data = JSON.parse(result.content[0].text);
    expect(data.emails).toHaveLength(1);
    expect(data.emails[0].relevance).toBe(0.95);
    expect(data.total_count).toBe(1);
  });

  it("passes limit to API", async () => {
    const api = {
      searchEmails: vi.fn().mockResolvedValue({
        data: [],
        meta: { total_count: 0, next_cursor: null },
      }),
    } as unknown as InboxedApi;

    await execute({ query: "test", limit: 25 }, api);
    expect(api.searchEmails).toHaveBeenCalledWith("test", 25);
  });

  it("defaults limit to 10", async () => {
    const api = {
      searchEmails: vi.fn().mockResolvedValue({
        data: [],
        meta: { total_count: 0, next_cursor: null },
      }),
    } as unknown as InboxedApi;

    await execute({ query: "test" }, api);
    expect(api.searchEmails).toHaveBeenCalledWith("test", 10);
  });

  it("maps API errors via mapApiError", async () => {
    const api = {
      searchEmails: vi.fn().mockRejectedValue(new TypeError("fetch failed")),
    } as unknown as InboxedApi;

    const result = await execute({ query: "test" }, api);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Cannot reach Inboxed API");
  });
});
