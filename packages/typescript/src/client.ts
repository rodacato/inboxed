import type {
  InboxedClientOptions,
  WaitOptions,
  ListOptions,
  ExtractOptions,
  Email,
  ApiInbox,
  ApiEmailDetail,
  ApiEmailSummary,
  ApiSearchResult,
  ApiPaginatedResponse,
} from "./types.js";
import {
  InboxedError,
  InboxedTimeoutError,
  InboxedNotFoundError,
  InboxedAuthError,
} from "./errors.js";
import { extractCode, extractUrls, extractLabeledValue } from "./extract.js";

export class InboxedClient {
  private baseUrl: string;
  private apiKey: string;

  constructor(options: InboxedClientOptions) {
    this.baseUrl = options.apiUrl.replace(/\/+$/, "");
    this.apiKey = options.apiKey;
  }

  // ── Core operations ────────────────────────────────────────

  async waitForEmail(inbox: string, options?: WaitOptions): Promise<Email> {
    const inboxRecord = await this.resolveInbox(inbox);
    const timeoutMs = options?.timeout ?? 30_000;
    const subjectPattern = options?.subject
      ? options.subject instanceof RegExp
        ? options.subject.source
        : options.subject
      : undefined;

    const body: Record<string, unknown> = {
      inbox_id: inboxRecord.id,
      timeout: Math.ceil(timeoutMs / 1000),
    };
    if (subjectPattern) {
      body.subject_pattern = subjectPattern;
    }

    const url = `${this.baseUrl}/api/v1/emails/wait`;
    const res = await fetch(url, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify(body),
    });

    if (res.status === 408) {
      throw new InboxedTimeoutError(inbox, timeoutMs);
    }

    this.assertOk(res);
    const summary = (await res.json()) as ApiEmailSummary;
    const detail = await this.fetchEmail(summary.id);
    return this.toEmail(detail);
  }

  async getLatestEmail(inbox: string): Promise<Email | null> {
    const inboxRecord = await this.resolveInbox(inbox);
    const res = await this.request<ApiPaginatedResponse<ApiEmailSummary>>(
      `/api/v1/inboxes/${inboxRecord.id}/emails?limit=1`
    );
    if (res.data.length === 0) return null;
    const detail = await this.fetchEmail(res.data[0].id);
    return this.toEmail(detail);
  }

  async listEmails(inbox: string, options?: ListOptions): Promise<Email[]> {
    const inboxRecord = await this.resolveInbox(inbox);
    const limit = options?.limit ?? 10;
    const res = await this.request<ApiPaginatedResponse<ApiEmailSummary>>(
      `/api/v1/inboxes/${inboxRecord.id}/emails?limit=${limit}`
    );
    const emails: Email[] = [];
    for (const summary of res.data) {
      const detail = await this.fetchEmail(summary.id);
      emails.push(this.toEmail(detail));
    }
    return emails;
  }

  async searchEmails(query: string, options?: ListOptions): Promise<Email[]> {
    const limit = options?.limit ?? 10;
    const res = await this.request<ApiPaginatedResponse<ApiSearchResult>>(
      `/api/v1/search?q=${encodeURIComponent(query)}&limit=${limit}`
    );
    const emails: Email[] = [];
    for (const summary of res.data) {
      const detail = await this.fetchEmail(summary.id);
      emails.push(this.toEmail(detail));
    }
    return emails;
  }

  async deleteInbox(inbox: string): Promise<void> {
    const inboxRecord = await this.resolveInbox(inbox);
    await this.request(`/api/v1/inboxes/${inboxRecord.id}`, {
      method: "DELETE",
    });
  }

  // ── Extraction ─────────────────────────────────────────────

  async extractCode(
    inbox: string,
    options?: ExtractOptions
  ): Promise<string | null> {
    const email = await this.getLatestEmail(inbox);
    if (!email) return null;
    const pattern = options?.pattern;
    return extractCode(email.bodyText, email.bodyHtml, pattern);
  }

  async extractLink(
    inbox: string,
    options?: ExtractOptions
  ): Promise<string | null> {
    const email = await this.getLatestEmail(inbox);
    if (!email) return null;

    let urls = extractUrls(email.bodyText, email.bodyHtml);
    if (options?.pattern) {
      const regex =
        options.pattern instanceof RegExp
          ? options.pattern
          : new RegExp(options.pattern, "i");
      urls = urls.filter((url) => regex.test(url));
    }
    return urls.length > 0 ? urls[0] : null;
  }

  async extractValue(
    inbox: string,
    label: string,
    options?: ExtractOptions
  ): Promise<string | null> {
    const email = await this.getLatestEmail(inbox);
    if (!email) return null;
    return extractLabeledValue(
      email.bodyText,
      email.bodyHtml,
      label,
      options?.pattern
    );
  }

  // ── Private ────────────────────────────────────────────────

  private headers(): Record<string, string> {
    return {
      "Content-Type": "application/json",
      Authorization: `Bearer ${this.apiKey}`,
    };
  }

  private async request<T>(
    path: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    const res = await fetch(url, {
      ...options,
      headers: { ...this.headers(), ...(options.headers as Record<string, string> || {}) },
    });
    this.assertOk(res);
    return res.json() as Promise<T>;
  }

  private assertOk(res: Response): void {
    if (res.ok) return;
    if (res.status === 401 || res.status === 403) {
      throw new InboxedAuthError();
    }
    if (res.status === 404) {
      throw new InboxedNotFoundError(res.url);
    }
    throw new InboxedError(
      `Inboxed API error: ${res.status} ${res.statusText}`
    );
  }

  private async resolveInbox(address: string): Promise<ApiInbox> {
    const res = await this.request<ApiPaginatedResponse<ApiInbox>>(
      `/api/v1/inboxes?address=${encodeURIComponent(address)}`
    );
    if (res.data.length === 0) {
      throw new InboxedNotFoundError(`Inbox: ${address}`);
    }
    return res.data[0];
  }

  private async fetchEmail(id: string): Promise<ApiEmailDetail> {
    return this.request<ApiEmailDetail>(`/api/v1/emails/${id}`);
  }

  private toEmail(detail: ApiEmailDetail): Email {
    return {
      id: detail.id,
      from: detail.from,
      to: detail.to,
      subject: detail.subject,
      bodyText: detail.body_text,
      bodyHtml: detail.body_html,
      receivedAt: new Date(detail.received_at),
    };
  }
}
