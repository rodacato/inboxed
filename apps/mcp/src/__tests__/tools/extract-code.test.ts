import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/extract-code.js";
import type { InboxedApi } from "../../ports/inboxed-api.js";

function createMockApi(bodyText: string | null, bodyHtml: string | null) {
  return {
    findInboxByAddress: vi.fn().mockResolvedValue({
      id: "inbox-1",
      address: "test@mail.inboxed.dev",
      email_count: 1,
      last_email_at: "2026-03-15T10:00:00Z",
      created_at: "2026-03-14T10:00:00Z",
    }),
    listEmails: vi.fn().mockResolvedValue({
      items: [{ id: "email-1" }],
      pagination: { has_more: false, total_count: 1, next_cursor: null },
    }),
    getEmail: vi.fn().mockResolvedValue({
      id: "email-1",
      subject: "Your verification code",
      body_text: bodyText,
      body_html: bodyHtml,
      attachments: [],
    }),
  } as unknown as InboxedApi;
}

describe("extract_code", () => {
  it("extracts a 6-digit code from plain text", async () => {
    const api = createMockApi("Your code is: 482910", null);
    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);

    const data = JSON.parse(result.content[0].text);
    expect(data.code).toBe("482910");
    expect(data.email_id).toBe("email-1");
  });

  it("extracts code from HTML when text is null", async () => {
    const api = createMockApi(
      null,
      "<p>Code: <strong>123456</strong></p>"
    );
    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);

    const data = JSON.parse(result.content[0].text);
    expect(data.code).toBe("123456");
  });

  it("supports custom pattern for alphanumeric codes", async () => {
    const api = createMockApi("Your code: AX8-KM2P", null);
    const result = await execute(
      {
        inbox: "test@mail.inboxed.dev",
        pattern: "[A-Z0-9]{3}-[A-Z0-9]{4}",
      },
      api
    );

    const data = JSON.parse(result.content[0].text);
    expect(data.code).toBe("AX8-KM2P");
  });

  it("returns null when no code found", async () => {
    const api = createMockApi("Welcome to our app!", null);
    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);

    expect(result.isError).toBeUndefined();
    const data = JSON.parse(result.content[0].text);
    expect(data.code).toBeNull();
    expect(data.message).toContain("No verification code");
  });

  it("maps API errors via mapApiError", async () => {
    const api = {
      findInboxByAddress: vi.fn().mockRejectedValue(new TypeError("fetch failed")),
    } as unknown as InboxedApi;

    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Cannot reach Inboxed API");
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
});
