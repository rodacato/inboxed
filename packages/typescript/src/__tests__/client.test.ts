import { describe, it, expect, vi, beforeEach } from "vitest";
import { InboxedClient } from "../client.js";
import {
  InboxedTimeoutError,
  InboxedNotFoundError,
  InboxedAuthError,
} from "../errors.js";

const INBOX_ADDRESS = "test@mail.inboxed.dev";
const INBOX_RESPONSE = {
  data: [
    {
      id: "inbox-1",
      address: INBOX_ADDRESS,
      email_count: 3,
      last_email_at: "2026-03-15T10:00:00Z",
      created_at: "2026-03-14T10:00:00Z",
    },
  ],
  meta: { total_count: 1, next_cursor: null },
};
const EMAIL_DETAIL = {
  id: "email-1",
  inbox_id: "inbox-1",
  inbox_address: INBOX_ADDRESS,
  from: "noreply@app.com",
  to: [INBOX_ADDRESS],
  cc: [],
  subject: "Your code is 482910",
  preview: "Your verification code...",
  body_text: "Your verification code is 482910",
  body_html: "<p>Your verification code is <b>482910</b></p>",
  received_at: "2026-03-15T10:00:00Z",
  source_type: "smtp",
  raw_headers: {},
  expires_at: null,
  attachments: [],
};
const EMAILS_LIST = {
  data: [
    {
      id: "email-1",
      inbox_id: "inbox-1",
      inbox_address: INBOX_ADDRESS,
      from: "noreply@app.com",
      subject: "Your code is 482910",
      preview: "Your verification code...",
      received_at: "2026-03-15T10:00:00Z",
    },
  ],
  meta: { total_count: 1, next_cursor: null },
};

function mockFetchSequence(...responses: Array<{ status?: number; ok?: boolean; body?: unknown }>) {
  const fn = vi.fn();
  for (const resp of responses) {
    fn.mockResolvedValueOnce({
      ok: resp.ok ?? true,
      status: resp.status ?? 200,
      statusText: "OK",
      url: "",
      json: () => Promise.resolve(resp.body),
    });
  }
  vi.stubGlobal("fetch", fn);
  return fn;
}

describe("InboxedClient", () => {
  let client: InboxedClient;

  beforeEach(() => {
    client = new InboxedClient({
      apiUrl: "http://localhost:3000",
      apiKey: "test-key",
    });
    vi.restoreAllMocks();
  });

  describe("waitForEmail", () => {
    it("returns email when one arrives", async () => {
      mockFetchSequence(
        { body: INBOX_RESPONSE },        // resolve inbox
        { body: EMAIL_DETAIL },           // wait returns summary
        { body: EMAIL_DETAIL }            // fetch full detail
      );

      const email = await client.waitForEmail(INBOX_ADDRESS);
      expect(email.id).toBe("email-1");
      expect(email.subject).toBe("Your code is 482910");
      expect(email.receivedAt).toBeInstanceOf(Date);
    });

    it("throws InboxedTimeoutError on 408", async () => {
      mockFetchSequence(
        { body: INBOX_RESPONSE },
        { status: 408, ok: false, body: null }
      );

      await expect(
        client.waitForEmail(INBOX_ADDRESS, { timeout: 5000 })
      ).rejects.toThrow(InboxedTimeoutError);
    });

    it("passes subject pattern to API", async () => {
      const mockFn = mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: EMAIL_DETAIL },
        { body: EMAIL_DETAIL }
      );

      await client.waitForEmail(INBOX_ADDRESS, { subject: /verify/i });
      const waitCall = JSON.parse(mockFn.mock.calls[1][1].body);
      expect(waitCall.subject_pattern).toBe("verify");
    });

    it("accepts string subject", async () => {
      const mockFn = mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: EMAIL_DETAIL },
        { body: EMAIL_DETAIL }
      );

      await client.waitForEmail(INBOX_ADDRESS, { subject: "verify" });
      const waitCall = JSON.parse(mockFn.mock.calls[1][1].body);
      expect(waitCall.subject_pattern).toBe("verify");
    });
  });

  describe("getLatestEmail", () => {
    it("returns the latest email", async () => {
      mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: EMAILS_LIST },
        { body: EMAIL_DETAIL }
      );

      const email = await client.getLatestEmail(INBOX_ADDRESS);
      expect(email).not.toBeNull();
      expect(email!.bodyText).toBe("Your verification code is 482910");
    });

    it("returns null for empty inbox", async () => {
      mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: { data: [], meta: { total_count: 0, next_cursor: null } } }
      );

      const email = await client.getLatestEmail(INBOX_ADDRESS);
      expect(email).toBeNull();
    });
  });

  describe("listEmails", () => {
    it("returns list of full email objects", async () => {
      mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: EMAILS_LIST },
        { body: EMAIL_DETAIL }
      );

      const emails = await client.listEmails(INBOX_ADDRESS);
      expect(emails).toHaveLength(1);
      expect(emails[0].from).toBe("noreply@app.com");
    });
  });

  describe("searchEmails", () => {
    it("returns search results as full emails", async () => {
      mockFetchSequence(
        { body: { data: [{ ...EMAIL_DETAIL, relevance: 0.95 }], meta: { total_count: 1, next_cursor: null } } },
        { body: EMAIL_DETAIL }
      );

      const emails = await client.searchEmails("verification");
      expect(emails).toHaveLength(1);
    });
  });

  describe("deleteInbox", () => {
    it("resolves inbox and deletes it", async () => {
      const mockFn = mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: null }
      );

      await client.deleteInbox(INBOX_ADDRESS);
      expect(mockFn.mock.calls[1][0]).toContain("/api/v1/inboxes/inbox-1");
      expect(mockFn.mock.calls[1][1].method).toBe("DELETE");
    });
  });

  describe("extractCode", () => {
    it("extracts code from latest email", async () => {
      mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: EMAILS_LIST },
        { body: EMAIL_DETAIL }
      );

      const code = await client.extractCode(INBOX_ADDRESS);
      expect(code).toBe("482910");
    });

    it("returns null for empty inbox", async () => {
      mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: { data: [], meta: { total_count: 0, next_cursor: null } } }
      );

      const code = await client.extractCode(INBOX_ADDRESS);
      expect(code).toBeNull();
    });
  });

  describe("extractLink", () => {
    it("extracts URL from latest email", async () => {
      const emailWithLink = {
        ...EMAIL_DETAIL,
        body_text: "Click https://app.com/verify?t=abc to verify",
      };
      mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: EMAILS_LIST },
        { body: emailWithLink }
      );

      const link = await client.extractLink(INBOX_ADDRESS);
      expect(link).toBe("https://app.com/verify?t=abc");
    });

    it("filters by pattern", async () => {
      const emailWithLinks = {
        ...EMAIL_DETAIL,
        body_text: "Visit https://app.com/home or https://app.com/reset?t=x",
      };
      mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: EMAILS_LIST },
        { body: emailWithLinks }
      );

      const link = await client.extractLink(INBOX_ADDRESS, {
        pattern: /reset/,
      });
      expect(link).toBe("https://app.com/reset?t=x");
    });

    it("returns null when no link matches", async () => {
      const emailNoLinks = { ...EMAIL_DETAIL, body_text: "No links" };
      mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: EMAILS_LIST },
        { body: emailNoLinks }
      );

      const link = await client.extractLink(INBOX_ADDRESS);
      expect(link).toBeNull();
    });
  });

  describe("extractValue", () => {
    it("extracts labeled value from latest email", async () => {
      const emailWithPassword = {
        ...EMAIL_DETAIL,
        body_text: "Temporary password: xK9#mP2!",
      };
      mockFetchSequence(
        { body: INBOX_RESPONSE },
        { body: EMAILS_LIST },
        { body: emailWithPassword }
      );

      const value = await client.extractValue(INBOX_ADDRESS, "password");
      expect(value).toBe("xK9#mP2!");
    });
  });

  describe("error handling", () => {
    it("throws InboxedNotFoundError for unknown inbox", async () => {
      mockFetchSequence({
        body: { data: [], meta: { total_count: 0, next_cursor: null } },
      });

      await expect(
        client.getLatestEmail("unknown@mail.inboxed.dev")
      ).rejects.toThrow(InboxedNotFoundError);
    });

    it("throws InboxedAuthError on 401", async () => {
      mockFetchSequence({ status: 401, ok: false, body: null });

      await expect(
        client.getLatestEmail(INBOX_ADDRESS)
      ).rejects.toThrow(InboxedAuthError);
    });

    it("throws InboxedAuthError on 403", async () => {
      mockFetchSequence({ status: 403, ok: false, body: null });

      await expect(
        client.getLatestEmail(INBOX_ADDRESS)
      ).rejects.toThrow(InboxedAuthError);
    });

    it("throws InboxedNotFoundError on 404", async () => {
      mockFetchSequence({ status: 404, ok: false, body: null });

      await expect(
        client.getLatestEmail(INBOX_ADDRESS)
      ).rejects.toThrow(InboxedNotFoundError);
    });
  });
});
