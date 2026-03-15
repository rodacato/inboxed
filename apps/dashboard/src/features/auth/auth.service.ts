import { apiClient, setStoredToken } from '$lib/api-client';

export async function authenticate(token: string): Promise<void> {
	await apiClient('/admin/status', {
		headers: { Authorization: `Bearer ${token}` }
	});
	setStoredToken(token);
}
