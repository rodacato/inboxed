import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/get-endpoint.js";
import type { InboxedApi } from "../../ports/inboxed-api.js";
import { ApiError } from "../../helpers/errors.js";

describe("get_endpoint", () => {
  it("returns endpoint details", async () => {
    const api = {
      getEndpoint: vi.fn().mockResolvedValue({
        token: "wh_abc",
        label: "Stripe",
        endpoint_type: "webhook",
        url: "/hook/wh_abc",
        request_count: 42,
        heartbeat_status: null,
        last_ping_at: null,
        expected_interval_seconds: null,
        created_at: "2026-03-14T10:00:00Z",
      }),
    } as unknown as InboxedApi;

    const result = await execute({ endpoint_token: "wh_abc" }, api);

    expect(result.isError).toBeUndefined();
    const data = JSON.parse(result.content[0].text);
    expect(data.token).toBe("wh_abc");
    expect(data.endpoint_type).toBe("webhook");
    expect(data.request_count).toBe(42);
  });

  it("returns error for unknown endpoint", async () => {
    const api = {
      getEndpoint: vi
        .fn()
        .mockRejectedValue(
          new ApiError(404, "Not Found", "/api/v1/endpoints/unknown")
        ),
    } as unknown as InboxedApi;

    const result = await execute({ endpoint_token: "unknown" }, api);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Not found");
  });
});
