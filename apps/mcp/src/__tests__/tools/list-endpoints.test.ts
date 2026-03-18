import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/list-endpoints.js";
import type { InboxedApi } from "../../ports/inboxed-api.js";

describe("list_endpoints", () => {
  it("returns all endpoints", async () => {
    const api = {
      listEndpoints: vi.fn().mockResolvedValue({
        items: [
          {
            token: "wh_abc",
            label: "Stripe",
            endpoint_type: "webhook",
            url: "/hook/wh_abc",
            request_count: 42,
            heartbeat_status: null,
            created_at: "2026-03-14T10:00:00Z",
          },
        ],
        pagination: { has_more: false, next_cursor: null, total_count: 1 },
      }),
    } as unknown as InboxedApi;

    const result = await execute({}, api);

    expect(result.isError).toBeUndefined();
    const data = JSON.parse(result.content[0].text);
    expect(data.endpoints).toHaveLength(1);
    expect(data.endpoints[0].token).toBe("wh_abc");
    expect(data.total_count).toBe(1);
  });

  it("passes type filter", async () => {
    const api = {
      listEndpoints: vi.fn().mockResolvedValue({
        items: [],
        pagination: { has_more: false, next_cursor: null, total_count: 0 },
      }),
    } as unknown as InboxedApi;

    await execute({ type: "heartbeat" }, api);
    expect(api.listEndpoints).toHaveBeenCalledWith({ type: "heartbeat", limit: undefined });
  });

  it("maps API errors", async () => {
    const api = {
      listEndpoints: vi.fn().mockRejectedValue(new TypeError("fetch failed")),
    } as unknown as InboxedApi;

    const result = await execute({}, api);
    expect(result.isError).toBe(true);
  });
});
