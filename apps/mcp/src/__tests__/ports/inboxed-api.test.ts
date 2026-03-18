import { describe, it, expect, vi, beforeEach } from "vitest";
import { InboxedApi } from "../../ports/inboxed-api.js";
import { ApiError } from "../../helpers/errors.js";

describe("InboxedApi", () => {
  let api: InboxedApi;

  beforeEach(() => {
    api = new InboxedApi("http://localhost:3000", "test-api-key");
    vi.restoreAllMocks();
  });

  it("sends Authorization header with API key", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve({ service: "inboxed", version: "1.0", status: "ok" }),
    });
    vi.stubGlobal("fetch", mockFetch);

    await api.getStatus();

    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:3000/api/v1/status",
      expect.objectContaining({
        headers: expect.objectContaining({
          Authorization: "Bearer test-api-key",
        }),
      })
    );
  });

  it("throws ApiError on non-2xx response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 404,
        statusText: "Not Found",
      })
    );

    await expect(api.getStatus()).rejects.toThrow(ApiError);
  });

  it("findInboxByAddress returns inbox or null", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            inboxes: [
              {
                id: "inbox-1",
                address: "test@mail.inboxed.dev",
                email_count: 3,
                last_email_at: null,
                created_at: "2026-03-14T10:00:00Z",
              },
            ],
            pagination: { total_count: 1, next_cursor: null, has_more: false },
          }),
      })
    );

    const inbox = await api.findInboxByAddress("test@mail.inboxed.dev");
    expect(inbox).not.toBeNull();
    expect(inbox!.id).toBe("inbox-1");
  });

  it("findInboxByAddress returns null for unknown address", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: () =>
          Promise.resolve({
            inboxes: [],
            pagination: { total_count: 0, next_cursor: null, has_more: false },
          }),
      })
    );

    const inbox = await api.findInboxByAddress("unknown@mail.inboxed.dev");
    expect(inbox).toBeNull();
  });

  it("waitForEmail returns null on 408 timeout", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 408,
        statusText: "Request Timeout",
      })
    );

    const result = await api.waitForEmail("inbox-1", undefined, 5);
    expect(result).toBeNull();
  });

  it("waitForEmail throws ApiError on other errors", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
        statusText: "Internal Server Error",
      })
    );

    await expect(api.waitForEmail("inbox-1")).rejects.toThrow(ApiError);
  });

  it("listInboxes calls correct endpoint", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve({
          inboxes: [{ id: "inbox-1", address: "test@mail.inboxed.dev" }],
          pagination: { total_count: 1, next_cursor: null, has_more: false },
        }),
    });
    vi.stubGlobal("fetch", mockFetch);

    const result = await api.listInboxes();
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:3000/api/v1/inboxes",
      expect.any(Object)
    );
    expect(result.items).toHaveLength(1);
  });

  it("deleteInbox sends DELETE request", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve(undefined),
    });
    vi.stubGlobal("fetch", mockFetch);

    await api.deleteInbox("inbox-1");
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:3000/api/v1/inboxes/inbox-1",
      expect.objectContaining({ method: "DELETE" })
    );
  });

  it("listEmails calls correct endpoint with limit", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve({
          emails: [],
          pagination: { total_count: 0, next_cursor: null, has_more: false },
        }),
    });
    vi.stubGlobal("fetch", mockFetch);

    await api.listEmails("inbox-1", 25);
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:3000/api/v1/inboxes/inbox-1/emails?limit=25",
      expect.any(Object)
    );
  });

  it("listEmails defaults limit to 10", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve({
          emails: [],
          pagination: { total_count: 0, next_cursor: null, has_more: false },
        }),
    });
    vi.stubGlobal("fetch", mockFetch);

    await api.listEmails("inbox-1");
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:3000/api/v1/inboxes/inbox-1/emails?limit=10",
      expect.any(Object)
    );
  });

  it("getEmail calls correct endpoint and unwraps response", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve({
          email: {
            id: "email-1",
            subject: "Test",
            body_text: "Hello",
          },
        }),
    });
    vi.stubGlobal("fetch", mockFetch);

    const result = await api.getEmail("email-1");
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:3000/api/v1/emails/email-1",
      expect.any(Object)
    );
    expect(result.id).toBe("email-1");
  });

  it("searchEmails calls correct endpoint with query and limit", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve({
          emails: [],
          pagination: { total_count: 0, next_cursor: null, has_more: false },
        }),
    });
    vi.stubGlobal("fetch", mockFetch);

    await api.searchEmails("hello world", 5);
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:3000/api/v1/search?q=hello%20world&limit=5",
      expect.any(Object)
    );
  });

  it("waitForEmail returns email on success", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
        json: () =>
          Promise.resolve({
            email: {
              id: "email-1",
              from: "noreply@app.com",
              subject: "Verify",
              preview: "Click...",
              received_at: "2026-03-15T10:00:00Z",
            },
          }),
      })
    );

    const result = await api.waitForEmail("inbox-1", "verify", 10);
    expect(result).not.toBeNull();
    expect(result!.id).toBe("email-1");
  });

  it("waitForEmail sends subject_pattern in body when provided", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () => Promise.resolve({ email: { id: "email-1" } }),
    });
    vi.stubGlobal("fetch", mockFetch);

    await api.waitForEmail("inbox-1", "verify", 15);
    const callBody = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(callBody.subject_pattern).toBe("verify");
    expect(callBody.timeout).toBe(15);
    expect(callBody.inbox_id).toBe("inbox-1");
  });

  it("waitForEmail omits subject_pattern when not provided", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () => Promise.resolve({ email: { id: "email-1" } }),
    });
    vi.stubGlobal("fetch", mockFetch);

    await api.waitForEmail("inbox-1");
    const callBody = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(callBody.subject_pattern).toBeUndefined();
  });

  it("strips trailing slash from base URL", async () => {
    const apiWithSlash = new InboxedApi(
      "http://localhost:3000/",
      "test-key"
    );
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve({ service: "inboxed", version: "1.0", status: "ok" }),
    });
    vi.stubGlobal("fetch", mockFetch);

    await apiWithSlash.getStatus();
    expect(mockFetch).toHaveBeenCalledWith(
      "http://localhost:3000/api/v1/status",
      expect.any(Object)
    );
  });

  it("createEndpoint unwraps response", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve({
          endpoint: {
            id: "ep-1",
            token: "wh_abc",
            url: "/hook/wh_abc",
            endpoint_type: "webhook",
            label: "Test",
          },
        }),
    });
    vi.stubGlobal("fetch", mockFetch);

    const result = await api.createEndpoint({ endpoint_type: "webhook", label: "Test" });
    expect(result.token).toBe("wh_abc");
  });

  it("getEndpoint unwraps response", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve({
          endpoint: {
            id: "ep-1",
            token: "wh_abc",
            endpoint_type: "heartbeat",
            heartbeat_status: "healthy",
          },
        }),
    });
    vi.stubGlobal("fetch", mockFetch);

    const result = await api.getEndpoint("wh_abc");
    expect(result.endpoint_type).toBe("heartbeat");
    expect(result.heartbeat_status).toBe("healthy");
  });

  it("listEndpoints returns paginated items", async () => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () =>
        Promise.resolve({
          endpoints: [{ id: "ep-1", token: "wh_abc" }],
          pagination: { total_count: 1, next_cursor: null, has_more: false },
        }),
    });
    vi.stubGlobal("fetch", mockFetch);

    const result = await api.listEndpoints({ type: "webhook" });
    expect(result.items).toHaveLength(1);
    expect(result.pagination.total_count).toBe(1);
  });

  it("waitForRequest returns null on 408 timeout", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 408,
        statusText: "Request Timeout",
      })
    );

    const result = await api.waitForRequest("wh_abc", { timeout: 2 });
    expect(result).toBeNull();
  });

  it("waitForRequest unwraps response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
        json: () =>
          Promise.resolve({
            request: {
              id: "req-1",
              method: "POST",
              body: '{"test":true}',
            },
          }),
      })
    );

    const result = await api.waitForRequest("wh_abc");
    expect(result).not.toBeNull();
    expect(result!.id).toBe("req-1");
  });
});
