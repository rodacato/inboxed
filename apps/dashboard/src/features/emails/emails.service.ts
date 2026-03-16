import { apiClient, getStoredToken } from '$lib/api-client';
import type { EmailSummary, EmailDetail } from './emails.types';
import type { Pagination } from '../projects/projects.types';

export async function fetchEmails(
	projectId: string,
	inboxId: string,
	params?: { limit?: number; after?: string }
): Promise<{ emails: EmailSummary[]; pagination: Pagination }> {
	const qs = new URLSearchParams();
	if (params?.limit) qs.set('limit', String(params.limit));
	if (params?.after) qs.set('after', params.after);
	const query = qs.toString() ? `?${qs}` : '';

	return (await apiClient(
		`/admin/projects/${projectId}/inboxes/${inboxId}/emails${query}`
	)) as { emails: EmailSummary[]; pagination: Pagination };
}

export async function fetchProjectEmails(
	projectId: string,
	params?: { limit?: number; after?: string; inbox_id?: string }
): Promise<{ emails: EmailSummary[]; pagination: Pagination }> {
	const qs = new URLSearchParams();
	if (params?.limit) qs.set('limit', String(params.limit));
	if (params?.after) qs.set('after', params.after);
	if (params?.inbox_id) qs.set('inbox_id', params.inbox_id);
	const query = qs.toString() ? `?${qs}` : '';

	return (await apiClient(
		`/admin/projects/${projectId}/emails${query}`
	)) as { emails: EmailSummary[]; pagination: Pagination };
}

export async function fetchEmail(id: string): Promise<{ email: EmailDetail }> {
	return (await apiClient(`/admin/emails/${id}`)) as { email: EmailDetail };
}

export async function fetchEmailRaw(id: string): Promise<string> {
	const token = getStoredToken();
	const res = await fetch(`/admin/emails/${id}/raw`, {
		headers: token ? { Authorization: `Bearer ${token}` } : {}
	});
	return res.text();
}

export async function deleteEmail(id: string): Promise<void> {
	await apiClient(`/admin/emails/${id}`, { method: 'DELETE' });
}

export async function purgeInbox(projectId: string, inboxId: string): Promise<number> {
	const result = (await apiClient(
		`/admin/projects/${projectId}/inboxes/${inboxId}/emails`,
		{ method: 'DELETE' }
	)) as { deleted_count: number };
	return result.deleted_count;
}
