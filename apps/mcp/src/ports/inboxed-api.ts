import type {
  ApiStatus,
  EmailDetail,
  EmailSummary,
  HttpEndpoint,
  HttpRequest,
  HttpRequestSummary,
  Inbox,
  PaginatedResponse,
  SearchResult,
} from "../types/index.js";
import { ApiError } from "../helpers/errors.js";

export class InboxedApi {
  private baseUrl: string;
  private apiKey: string;

  constructor(baseUrl: string, apiKey: string) {
    this.baseUrl = baseUrl.replace(/\/+$/, "");
    this.apiKey = apiKey;
  }

  private async request<T>(
    path: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    const res = await fetch(url, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
        ...(options.headers || {}),
      },
    });

    if (!res.ok) {
      throw new ApiError(res.status, res.statusText, url);
    }

    return res.json() as Promise<T>;
  }

  // Status
  async getStatus(): Promise<ApiStatus> {
    return this.request<ApiStatus>("/api/v1/status");
  }

  // Inbox operations
  async listInboxes(): Promise<PaginatedResponse<Inbox>> {
    return this.request<PaginatedResponse<Inbox>>("/api/v1/inboxes");
  }

  async findInboxByAddress(address: string): Promise<Inbox | null> {
    const res = await this.request<PaginatedResponse<Inbox>>(
      `/api/v1/inboxes?address=${encodeURIComponent(address)}`
    );
    return res.data.length > 0 ? res.data[0] : null;
  }

  async deleteInbox(id: string): Promise<void> {
    await this.request<void>(`/api/v1/inboxes/${id}`, { method: "DELETE" });
  }

  // Email operations
  async listEmails(
    inboxId: string,
    limit: number = 10
  ): Promise<PaginatedResponse<EmailSummary>> {
    return this.request<PaginatedResponse<EmailSummary>>(
      `/api/v1/inboxes/${inboxId}/emails?limit=${limit}`
    );
  }

  async getEmail(id: string): Promise<EmailDetail> {
    return this.request<EmailDetail>(`/api/v1/emails/${id}`);
  }

  async waitForEmail(
    inboxId: string,
    subjectPattern?: string,
    timeoutSeconds: number = 30
  ): Promise<EmailSummary | null> {
    const body: Record<string, unknown> = {
      inbox_id: inboxId,
      timeout: timeoutSeconds,
    };
    if (subjectPattern) {
      body.subject_pattern = subjectPattern;
    }

    const url = `${this.baseUrl}/api/v1/emails/wait`;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify(body),
    });

    if (res.status === 408) {
      return null;
    }

    if (!res.ok) {
      throw new ApiError(res.status, res.statusText, url);
    }

    return res.json() as Promise<EmailSummary>;
  }

  // HTTP Endpoints
  async createEndpoint(params: {
    project?: string;
    endpoint_type?: string;
    label?: string;
    expected_interval_seconds?: number;
  }): Promise<{ data: HttpEndpoint }> {
    return this.request<{ data: HttpEndpoint }>("/api/v1/endpoints", {
      method: "POST",
      body: JSON.stringify(params),
    });
  }

  async getEndpoint(token: string): Promise<{ data: HttpEndpoint }> {
    return this.request<{ data: HttpEndpoint }>(
      `/api/v1/endpoints/${encodeURIComponent(token)}`
    );
  }

  async listEndpoints(params?: {
    type?: string;
    limit?: number;
  }): Promise<PaginatedResponse<HttpEndpoint>> {
    const qs = new URLSearchParams();
    if (params?.type) qs.set("type", params.type);
    if (params?.limit) qs.set("limit", String(params.limit));
    const query = qs.toString() ? `?${qs}` : "";
    return this.request<PaginatedResponse<HttpEndpoint>>(
      `/api/v1/endpoints${query}`
    );
  }

  async deleteEndpoint(token: string): Promise<void> {
    await this.request<void>(
      `/api/v1/endpoints/${encodeURIComponent(token)}`,
      { method: "DELETE" }
    );
  }

  // HTTP Requests
  async listRequests(
    token: string,
    params?: { limit?: number; method?: string }
  ): Promise<PaginatedResponse<HttpRequestSummary>> {
    const qs = new URLSearchParams();
    if (params?.limit) qs.set("limit", String(params.limit));
    if (params?.method) qs.set("method", params.method);
    const query = qs.toString() ? `?${qs}` : "";
    return this.request<PaginatedResponse<HttpRequestSummary>>(
      `/api/v1/endpoints/${encodeURIComponent(token)}/requests${query}`
    );
  }

  async getRequest(
    token: string,
    requestId: string
  ): Promise<{ data: HttpRequest }> {
    return this.request<{ data: HttpRequest }>(
      `/api/v1/endpoints/${encodeURIComponent(token)}/requests/${requestId}`
    );
  }

  async getLatestRequest(
    token: string,
    method?: string
  ): Promise<HttpRequest | null> {
    const qs = new URLSearchParams({ limit: "1" });
    if (method) qs.set("method", method);
    const res = await this.request<PaginatedResponse<HttpRequest>>(
      `/api/v1/endpoints/${encodeURIComponent(token)}/requests?${qs}`
    );
    return res.data.length > 0 ? res.data[0] : null;
  }

  async waitForRequest(
    token: string,
    params?: { method?: string; timeout?: number }
  ): Promise<HttpRequest | null> {
    const body: Record<string, unknown> = {};
    if (params?.method) body.method = params.method;
    if (params?.timeout) body.timeout = params.timeout;

    const url = `${this.baseUrl}/api/v1/endpoints/${encodeURIComponent(token)}/requests/wait`;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify(body),
    });

    if (res.status === 408) {
      return null;
    }

    if (!res.ok) {
      throw new ApiError(res.status, res.statusText, url);
    }

    const json = (await res.json()) as { data: HttpRequest };
    return json.data;
  }

  // Search
  async searchEmails(
    query: string,
    limit: number = 10
  ): Promise<PaginatedResponse<SearchResult>> {
    return this.request<PaginatedResponse<SearchResult>>(
      `/api/v1/search?q=${encodeURIComponent(query)}&limit=${limit}`
    );
  }
}
