import { describe, it, expect, vi } from "vitest";
import { execute } from "../../tools/get-email.js";
import type { InboxedApi } from "../../ports/inboxed-api.js";
import { ApiError } from "../../helpers/errors.js";

describe("get_email", () => {
  it("returns full email detail", async () => {
    const api = {
      getEmail: vi.fn().mockResolvedValue({
        id: "email-1",
        inbox_id: "inbox-1",
        inbox_address: "test@mail.inboxed.dev",
        from: "noreply@app.com",
        to: ["test@mail.inboxed.dev"],
        cc: [],
        subject: "Welcome",
        body_text: "Hello world",
        body_html: "<p>Hello world</p>",
        received_at: "2026-03-15T10:00:00Z",
        source_type: "smtp",
        raw_headers: {},
        expires_at: null,
        attachments: [
          {
            id: "att-1",
            filename: "doc.pdf",
            content_type: "application/pdf",
            size_bytes: 1024,
            inline: false,
          },
        ],
      }),
    } as unknown as InboxedApi;

    const result = await execute({ email_id: "email-1" }, api);

    expect(result.isError).toBeUndefined();
    const data = JSON.parse(result.content[0].text);
    expect(data.id).toBe("email-1");
    expect(data.body_text).toBe("Hello world");
    expect(data.attachments).toHaveLength(1);
    expect(data.attachments[0].filename).toBe("doc.pdf");
  });

  it("returns error for missing email (ApiError)", async () => {
    const api = {
      getEmail: vi
        .fn()
        .mockRejectedValue(
          new ApiError(404, "Not Found", "/api/v1/emails/missing")
        ),
    } as unknown as InboxedApi;

    const result = await execute({ email_id: "missing" }, api);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Not found");
  });

  it("maps network errors via mapApiError", async () => {
    const api = {
      getEmail: vi
        .fn()
        .mockRejectedValue(new TypeError("fetch failed")),
    } as unknown as InboxedApi;

    const result = await execute({ email_id: "email-1" }, api);
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain("Cannot reach Inboxed API");
  });
});
