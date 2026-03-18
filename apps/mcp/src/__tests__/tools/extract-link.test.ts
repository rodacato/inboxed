import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/extract-link.js";
import type { InboxedApi } from "../../ports/inboxed-api.js";

function createMockApi(bodyText: string | null, bodyHtml: string | null) {
  return {
    findInboxByAddress: vi.fn().mockResolvedValue({
      id: "inbox-1",
      address: "test@mail.inboxed.dev",
      email_count: 1,
    }),
    listEmails: vi.fn().mockResolvedValue({
      items: [{ id: "email-1" }],
      pagination: { has_more: false, total_count: 1, next_cursor: null },
    }),
    getEmail: vi.fn().mockResolvedValue({
      id: "email-1",
      subject: "Verify your email",
      body_text: bodyText,
      body_html: bodyHtml,
      attachments: [],
    }),
  } as unknown as InboxedApi;
}

describe("extract_link", () => {
  it("extracts a URL from plain text", async () => {
    const api = createMockApi(
      "Click here: https://app.example.com/verify?token=abc123",
      null
    );
    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);

    const data = JSON.parse(result.content[0].text);
    expect(data.url).toBe("https://app.example.com/verify?token=abc123");
  });

  it("extracts URL from HTML href when text is null", async () => {
    const api = createMockApi(
      null,
      '<a href="https://app.example.com/verify?token=abc">Verify</a>'
    );
    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);

    const data = JSON.parse(result.content[0].text);
    expect(data.url).toBe("https://app.example.com/verify?token=abc");
  });

  it("filters URLs by link_pattern", async () => {
    const api = createMockApi(
      "Visit https://example.com or https://app.example.com/reset?token=x",
      null
    );
    const result = await execute(
      { inbox: "test@mail.inboxed.dev", link_pattern: "reset" },
      api
    );

    const data = JSON.parse(result.content[0].text);
    expect(data.url).toBe("https://app.example.com/reset?token=x");
  });

  it("returns null when no matching link found", async () => {
    const api = createMockApi("No links here.", null);
    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);

    const data = JSON.parse(result.content[0].text);
    expect(data.url).toBeNull();
    expect(data.message).toContain("No matching link");
  });

  it("returns error for unknown inbox", async () => {
    const api = {
      findInboxByAddress: vi.fn().mockResolvedValue(null),
    } as unknown as InboxedApi;

    const result = await execute({ inbox: "unknown@mail.inboxed.dev" }, api);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Inbox not found");
  });

  it("returns error when inbox has no emails", async () => {
    const api = {
      findInboxByAddress: vi.fn().mockResolvedValue({
        id: "inbox-1",
        address: "test@mail.inboxed.dev",
        email_count: 0,
      }),
      listEmails: vi.fn().mockResolvedValue({
        items: [],
        pagination: { has_more: false, total_count: 0, next_cursor: null },
      }),
    } as unknown as InboxedApi;

    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("No emails");
  });

  it("maps API errors via mapApiError", async () => {
    const api = {
      findInboxByAddress: vi.fn().mockRejectedValue(new TypeError("fetch failed")),
    } as unknown as InboxedApi;

    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);
    expect(result.isError).toBe(true);
  });
});
