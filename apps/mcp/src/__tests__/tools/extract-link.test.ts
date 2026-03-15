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
      data: [{ id: "email-1" }],
      meta: { total_count: 1, next_cursor: null },
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
});
