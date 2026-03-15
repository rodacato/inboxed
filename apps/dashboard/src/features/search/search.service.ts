import { apiClient } from '$lib/api-client';
import type { SearchResult } from './search.types';
import type { Pagination } from '../projects/projects.types';

export async function searchEmails(
	query: string,
	params?: { limit?: number; after?: string }
): Promise<{ emails: SearchResult[]; pagination: Pagination }> {
	const qs = new URLSearchParams({ q: query });
	if (params?.limit) qs.set('limit', String(params.limit));
	if (params?.after) qs.set('after', params.after);

	return (await apiClient(`/admin/search?${qs}`)) as {
		emails: SearchResult[];
		pagination: Pagination;
	};
}
