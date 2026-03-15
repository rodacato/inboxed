import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/extract-value.js";
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
      subject: "Your account details",
      body_text: bodyText,
      body_html: bodyHtml,
      attachments: [],
    }),
  } as unknown as InboxedApi;
}

describe("extract_value", () => {
  it("extracts a temporary password", async () => {
    const api = createMockApi("Temporary password: xK9#mP2!", null);
    const result = await execute(
      { inbox: "test@mail.inboxed.dev", label: "password" },
      api
    );

    const data = JSON.parse(result.content[0].text);
    expect(data.value).toBe("xK9#mP2!");
    expect(data.label).toBe("password");
  });

  it("extracts a username", async () => {
    const api = createMockApi("Username: user_8a7c3f", null);
    const result = await execute(
      { inbox: "test@mail.inboxed.dev", label: "Username" },
      api
    );

    const data = JSON.parse(result.content[0].text);
    expect(data.value).toBe("user_8a7c3f");
  });

  it("extracts a reference number", async () => {
    const api = createMockApi("Reference # ORD-99281", null);
    const result = await execute(
      { inbox: "test@mail.inboxed.dev", label: "Reference" },
      api
    );

    const data = JSON.parse(result.content[0].text);
    expect(data.value).toBe("ORD-99281");
  });

  it("supports custom value pattern", async () => {
    const api = createMockApi(
      "Tracking number: 1Z999AA10123456784",
      null
    );
    const result = await execute(
      {
        inbox: "test@mail.inboxed.dev",
        label: "Tracking number",
        pattern: "[A-Z0-9]+",
      },
      api
    );

    const data = JSON.parse(result.content[0].text);
    expect(data.value).toBe("1Z999AA10123456784");
  });

  it("returns null when label not found", async () => {
    const api = createMockApi("Welcome to our app!", null);
    const result = await execute(
      { inbox: "test@mail.inboxed.dev", label: "password" },
      api
    );

    const data = JSON.parse(result.content[0].text);
    expect(data.value).toBeNull();
    expect(data.message).toContain("No value found");
  });

  it("returns error for unknown inbox", async () => {
    const api = {
      findInboxByAddress: vi.fn().mockResolvedValue(null),
    } as unknown as InboxedApi;

    const result = await execute(
      { inbox: "unknown@mail.inboxed.dev", label: "password" },
      api
    );
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
        data: [],
        meta: { total_count: 0, next_cursor: null },
      }),
    } as unknown as InboxedApi;

    const result = await execute(
      { inbox: "test@mail.inboxed.dev", label: "password" },
      api
    );
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("No emails");
  });

  it("maps API errors via mapApiError", async () => {
    const api = {
      findInboxByAddress: vi.fn().mockRejectedValue(new TypeError("fetch failed")),
    } as unknown as InboxedApi;

    const result = await execute(
      { inbox: "test@mail.inboxed.dev", label: "password" },
      api
    );
    expect(result.isError).toBe(true);
  });
});
