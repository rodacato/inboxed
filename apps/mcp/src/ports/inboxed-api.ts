import type { Message, ApiStatus } from "../types/index.js";

export class InboxedApi {
  private baseUrl: string;
  private apiKey: string;

  constructor(baseUrl: string, apiKey: string) {
    this.baseUrl = baseUrl;
    this.apiKey = apiKey;
  }

  private async request<T>(path: string, options: RequestInit = {}): Promise<T> {
    const res = await fetch(`${this.baseUrl}${path}`, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
        ...(options.headers || {}),
      },
    });

    if (!res.ok) {
      throw new Error(`Inboxed API error: ${res.status} ${res.statusText}`);
    }

    return res.json() as Promise<T>;
  }

  async getStatus(): Promise<ApiStatus> {
    return this.request<ApiStatus>("/api/v1/status");
  }

  // TODO: Implement when API endpoints exist
  async getMessages(_limit?: number): Promise<Message[]> {
    return [];
  }

  async getMessage(_id: string): Promise<Message | null> {
    return null;
  }

  async searchMessages(_query: string): Promise<Message[]> {
    return [];
  }
}
