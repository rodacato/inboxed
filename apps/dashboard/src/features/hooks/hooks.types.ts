export interface HttpEndpoint {
	id: string;
	endpoint_type: 'webhook' | 'form' | 'heartbeat';
	token: string;
	label: string | null;
	description: string | null;
	url: string;
	allowed_methods: string[];
	allowed_ips: string[];
	max_body_bytes: number;
	request_count: number;
	response_mode: string | null;
	response_redirect_url: string | null;
	expected_interval_seconds: number | null;
	heartbeat_status: 'pending' | 'healthy' | 'late' | 'down' | null;
	last_ping_at: string | null;
	status_changed_at: string | null;
	created_at: string;
	updated_at: string;
}

export interface EndpointInfo {
	token: string;
	label: string | null;
	endpoint_type: 'webhook' | 'form' | 'heartbeat';
	url?: string;
}

export interface HttpRequestSummary {
	id: string;
	method: string;
	path: string | null;
	content_type: string | null;
	ip_address: string | null;
	size_bytes: number;
	received_at: string;
	endpoint?: EndpointInfo;
}

export interface HttpRequestDetail extends HttpRequestSummary {
	query_string: string | null;
	headers: Record<string, string>;
	body: string | null;
}

export interface CreateEndpointParams {
	endpoint_type: string;
	label?: string;
	description?: string;
	allowed_methods?: string[];
	expected_interval_seconds?: number;
	response_mode?: string;
	response_redirect_url?: string;
}
