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

export interface PaginatedResponse<T> {
  data: T[];
  meta: {
    total_count: number;
    next_cursor: string | null;
  };
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
