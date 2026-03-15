import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/wait-for-email.js";
import type { InboxedApi } from "../../ports/inboxed-api.js";

function createMockApi(overrides: Partial<InboxedApi> = {}): InboxedApi {
  return {
    getStatus: vi.fn(),
    listInboxes: vi.fn(),
    findInboxByAddress: vi.fn().mockResolvedValue({
      id: "inbox-1",
      address: "test@mail.inboxed.dev",
      email_count: 0,
      last_email_at: null,
      created_at: "2026-03-14T10:00:00Z",
    }),
    deleteInbox: vi.fn(),
    listEmails: vi.fn(),
    getEmail: vi.fn(),
    waitForEmail: vi.fn().mockResolvedValue(null),
    searchEmails: vi.fn(),
    ...overrides,
  } as unknown as InboxedApi;
}

describe("wait_for_email", () => {
  it("returns found: true when email arrives", async () => {
    const api = createMockApi({
      waitForEmail: vi.fn().mockResolvedValue({
        id: "email-1",
        inbox_id: "inbox-1",
        inbox_address: "test@mail.inboxed.dev",
        from: "noreply@app.com",
        subject: "Verify your email",
        preview: "Click the link...",
        received_at: "2026-03-15T10:00:00Z",
      }),
    });

    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);
    const data = JSON.parse(result.content[0].text);
    expect(data.found).toBe(true);
    expect(data.email.subject).toBe("Verify your email");
  });

  it("returns found: false on timeout (NOT an error)", async () => {
    const api = createMockApi();
    const result = await execute(
      { inbox: "test@mail.inboxed.dev", timeout_seconds: 5 },
      api
    );

    expect(result.isError).toBeUndefined();
    const data = JSON.parse(result.content[0].text);
    expect(data.found).toBe(false);
    expect(data.message).toContain("5 seconds");
  });

  it("passes subject_pattern to API", async () => {
    const api = createMockApi();
    await execute(
      { inbox: "test@mail.inboxed.dev", subject_pattern: "verify" },
      api
    );

    expect(api.waitForEmail).toHaveBeenCalledWith("inbox-1", "verify", 30);
  });

  it("returns error for unknown inbox", async () => {
    const api = createMockApi({
      findInboxByAddress: vi.fn().mockResolvedValue(null),
    });
    const result = await execute({ inbox: "unknown@mail.inboxed.dev" }, api);
    expect(result.isError).toBe(true);
  });
});
