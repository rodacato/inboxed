export interface Project {
	id: string;
	name: string;
	slug: string;
	default_ttl_hours: number | null;
	max_inbox_count: number;
	inbox_count: number;
	created_at: string;
}

export interface ApiKey {
	id: string;
	label: string;
	token_prefix: string;
	last_used_at: string | null;
	created_at: string;
}

export interface ApiKeyWithToken extends ApiKey {
	token: string;
}

export interface Pagination {
	has_more: boolean;
	next_cursor: string | null;
	total_count: number;
}
