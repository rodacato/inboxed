// Types matching REST API responses (spec 003 serializers)

export interface Inbox {
  id: string;
  address: string;
  email_count: number;
  last_email_at: string | null;
  created_at: string;
}

export interface EmailSummary {
  id: string;
  inbox_id: string;
  inbox_address: string;
  from: string;
  subject: string;
  preview: string;
  received_at: string;
}

export interface EmailDetail extends EmailSummary {
  to: string[];
  cc: string[];
  body_text: string | null;
  body_html: string | null;
  source_type: string;
  raw_headers: Record<string, string>;
  expires_at: string | null;
  attachments: AttachmentMeta[];
}

export interface AttachmentMeta {
  id: string;
  filename: string;
  content_type: string;
  size_bytes: number;
  inline: boolean;
}

export interface SearchResult extends EmailSummary {
  relevance: number;
}

export interface Pagination {
  has_more: boolean;
  next_cursor: string | null;
  total_count: number;
}

export interface PaginatedResponse<T> {
  items: T[];
  pagination: Pagination;
}

// HTTP Catcher types
export interface HttpEndpoint {
  id: string;
  endpoint_type: "webhook" | "form" | "heartbeat";
  token: string;
  label: string | null;
  url: string;
  request_count: number;
  heartbeat_status: string | null;
  last_ping_at: string | null;
  expected_interval_seconds: number | null;
  created_at: string;
}

export interface HttpRequest {
  id: string;
  method: string;
  path: string | null;
  query_string: string | null;
  headers: Record<string, string>;
  body: string | null;
  content_type: string | null;
  ip_address: string | null;
  size_bytes: number;
  received_at: string;
}

export interface HttpRequestSummary {
  id: string;
  method: string;
  path: string | null;
  content_type: string | null;
  ip_address: string | null;
  size_bytes: number;
  received_at: string;
}

export interface ApiStatus {
  service: string;
  version: string;
  status: string;
}

// MCP tool result helpers
export type ToolResult = {
  [key: string]: unknown;
  content: Array<{ type: "text"; text: string }>;
  isError?: boolean;
};
