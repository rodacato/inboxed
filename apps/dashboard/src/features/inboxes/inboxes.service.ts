import { apiClient } from '$lib/api-client';
import type { Inbox } from './inboxes.types';
import type { Pagination } from '../projects/projects.types';

export async function fetchInboxes(
	projectId: string,
	params?: { limit?: number; after?: string }
): Promise<{ inboxes: Inbox[]; pagination: Pagination }> {
	const qs = new URLSearchParams();
	if (params?.limit) qs.set('limit', String(params.limit));
	if (params?.after) qs.set('after', params.after);
	const query = qs.toString() ? `?${qs}` : '';

	return (await apiClient(`/admin/projects/${projectId}/inboxes${query}`)) as {
		inboxes: Inbox[];
		pagination: Pagination;
	};
}

export async function deleteInbox(projectId: string, inboxId: string): Promise<void> {
	await apiClient(`/admin/projects/${projectId}/inboxes/${inboxId}`, {
		method: 'DELETE'
	});
}
