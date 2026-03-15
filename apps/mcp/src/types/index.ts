export interface Message {
  id: string;
  from: string;
  to: string[];
  subject: string;
  body_html: string | null;
  body_text: string | null;
  received_at: string;
}

export interface ApiStatus {
  service: string;
  version: string;
  status: string;
}
