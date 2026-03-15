export interface InboxedClientOptions {
  apiUrl: string;
  apiKey: string;
}

export interface WaitOptions {
  subject?: string | RegExp;
  timeout?: number; // ms, default: 30_000
}

export interface ListOptions {
  limit?: number; // default: 10
}

export interface ExtractOptions {
  pattern?: string | RegExp;
}

export interface Email {
  id: string;
  from: string;
  to: string[];
  subject: string;
  bodyText: string | null;
  bodyHtml: string | null;
  receivedAt: Date;
}

export interface Inbox {
  id: string;
  address: string;
  emailCount: number;
}

// Internal API response types
export interface ApiInbox {
  id: string;
  address: string;
  email_count: number;
  last_email_at: string | null;
  created_at: string;
}

export interface ApiEmailSummary {
  id: string;
  inbox_id: string;
  inbox_address: string;
  from: string;
  subject: string;
  preview: string;
  received_at: string;
}

export interface ApiEmailDetail extends ApiEmailSummary {
  to: string[];
  cc: string[];
  body_text: string | null;
  body_html: string | null;
  source_type: string;
  raw_headers: Record<string, string>;
  expires_at: string | null;
  attachments: Array<{
    id: string;
    filename: string;
    content_type: string;
    size_bytes: number;
    inline: boolean;
  }>;
}

export interface ApiSearchResult extends ApiEmailSummary {
  relevance: number;
}

export interface ApiPaginatedResponse<T> {
  data: T[];
  meta: {
    total_count: number;
    next_cursor: string | null;
  };
}
