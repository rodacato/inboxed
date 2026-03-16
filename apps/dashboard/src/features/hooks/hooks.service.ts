import { apiClient } from '$lib/api-client';
import type {
	HttpEndpoint,
	HttpRequestSummary,
	HttpRequestDetail,
	CreateEndpointParams
} from './hooks.types';
import type { Pagination } from '../projects/projects.types';

export async function fetchEndpoints(
	projectId: string,
	params?: { type?: string; limit?: number; after?: string }
): Promise<{ endpoints: HttpEndpoint[]; pagination: Pagination }> {
	const qs = new URLSearchParams();
	if (params?.type) qs.set('type', params.type);
	if (params?.limit) qs.set('limit', String(params.limit));
	if (params?.after) qs.set('after', params.after);
	const query = qs.toString() ? `?${qs}` : '';

	return (await apiClient(
		`/admin/projects/${projectId}/endpoints${query}`
	)) as { endpoints: HttpEndpoint[]; pagination: Pagination };
}

export async function fetchEndpoint(
	projectId: string,
	token: string
): Promise<{ endpoint: HttpEndpoint }> {
	return (await apiClient(
		`/admin/projects/${projectId}/endpoints/${token}`
	)) as { endpoint: HttpEndpoint };
}

export async function createEndpoint(
	projectId: string,
	params: CreateEndpointParams
): Promise<{ endpoint: HttpEndpoint }> {
	return (await apiClient(`/admin/projects/${projectId}/endpoints`, {
		method: 'POST',
		body: JSON.stringify(params)
	})) as { endpoint: HttpEndpoint };
}

export async function updateEndpoint(
	projectId: string,
	token: string,
	params: Partial<CreateEndpointParams>
): Promise<{ endpoint: HttpEndpoint }> {
	return (await apiClient(`/admin/projects/${projectId}/endpoints/${token}`, {
		method: 'PATCH',
		body: JSON.stringify(params)
	})) as { endpoint: HttpEndpoint };
}

export async function deleteEndpoint(projectId: string, token: string): Promise<void> {
	await apiClient(`/admin/projects/${projectId}/endpoints/${token}`, {
		method: 'DELETE'
	});
}

export async function purgeEndpointRequests(
	projectId: string,
	token: string
): Promise<number> {
	const result = (await apiClient(
		`/admin/projects/${projectId}/endpoints/${token}/purge`,
		{ method: 'DELETE' }
	)) as { deleted_count: number };
	return result.deleted_count;
}

export async function fetchProjectRequests(
	projectId: string,
	params?: { endpoint_token?: string; method?: string; limit?: number; after?: string }
): Promise<{ requests: HttpRequestSummary[]; pagination: Pagination }> {
	const qs = new URLSearchParams();
	if (params?.endpoint_token) qs.set('endpoint_token', params.endpoint_token);
	if (params?.method) qs.set('method', params.method);
	if (params?.limit) qs.set('limit', String(params.limit));
	if (params?.after) qs.set('after', params.after);
	const query = qs.toString() ? `?${qs}` : '';

	return (await apiClient(
		`/admin/projects/${projectId}/requests${query}`
	)) as { requests: HttpRequestSummary[]; pagination: Pagination };
}

export async function fetchProjectRequest(
	projectId: string,
	requestId: string
): Promise<{ request: HttpRequestDetail }> {
	return (await apiClient(
		`/admin/projects/${projectId}/requests/${requestId}`
	)) as { request: HttpRequestDetail };
}

export async function fetchRequests(
	projectId: string,
	token: string,
	params?: { method?: string; limit?: number; after?: string }
): Promise<{ requests: HttpRequestSummary[]; pagination: Pagination }> {
	const qs = new URLSearchParams();
	if (params?.method) qs.set('method', params.method);
	if (params?.limit) qs.set('limit', String(params.limit));
	if (params?.after) qs.set('after', params.after);
	const query = qs.toString() ? `?${qs}` : '';

	return (await apiClient(
		`/admin/projects/${projectId}/endpoints/${token}/requests${query}`
	)) as { requests: HttpRequestSummary[]; pagination: Pagination };
}

export async function fetchRequest(
	projectId: string,
	token: string,
	requestId: string
): Promise<{ request: HttpRequestDetail }> {
	return (await apiClient(
		`/admin/projects/${projectId}/endpoints/${token}/requests/${requestId}`
	)) as { request: HttpRequestDetail };
}

export async function deleteRequest(
	projectId: string,
	token: string,
	requestId: string
): Promise<void> {
	await apiClient(
		`/admin/projects/${projectId}/endpoints/${token}/requests/${requestId}`,
		{ method: 'DELETE' }
	);
}
