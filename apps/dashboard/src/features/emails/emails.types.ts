export interface EmailSummary {
	id: string;
	from: string;
	to: string[];
	subject: string;
	preview: string;
	has_attachments: boolean;
	attachment_count: number;
	source_type: string;
	received_at: string;
}

export interface EmailDetail {
	id: string;
	inbox_id: string;
	from: string;
	to: string[];
	cc: string[];
	subject: string;
	body_html: string | null;
	body_text: string | null;
	raw_headers: Record<string, string>;
	source_type: string;
	received_at: string;
	expires_at: string;
	attachments: Attachment[];
}

export interface Attachment {
	id: string;
	filename: string;
	content_type: string;
	size_bytes: number;
	inline: boolean;
	download_url: string;
}
