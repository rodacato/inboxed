import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/wait-for-email.js";
import type { InboxedApi } from "../../ports/inboxed-api.js";

function createMockApi(overrides: Partial<InboxedApi> = {}): InboxedApi {
  return {
    getStatus: vi.fn(),
    listInboxes: vi.fn(),
    findInboxByAddress: vi.fn(),
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

  it("passes inbox address and subject_pattern directly to API", async () => {
    const api = createMockApi();
    await execute(
      { inbox: "test@mail.inboxed.dev", subject_pattern: "verify" },
      api
    );

    expect(api.waitForEmail).toHaveBeenCalledWith(
      "test@mail.inboxed.dev",
      "verify",
      30
    );
  });

  it("defaults timeout to 30 seconds", async () => {
    const api = createMockApi();
    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);

    expect(api.waitForEmail).toHaveBeenCalledWith(
      "test@mail.inboxed.dev",
      undefined,
      30
    );
    const data = JSON.parse(result.content[0].text);
    expect(data.message).toContain("30 seconds");
  });

  it("maps API errors via mapApiError", async () => {
    const api = createMockApi({
      waitForEmail: vi
        .fn()
        .mockRejectedValue(new TypeError("fetch failed")),
    });
    const result = await execute({ inbox: "test@mail.inboxed.dev" }, api);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Cannot reach Inboxed API");
  });
});
