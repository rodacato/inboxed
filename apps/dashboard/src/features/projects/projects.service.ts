import { apiClient } from '$lib/api-client';
import type { Project, ApiKey, ApiKeyWithToken } from './projects.types';

export async function fetchProjects(): Promise<{ projects: Project[] }> {
	return (await apiClient('/admin/projects')) as { projects: Project[] };
}

export async function fetchProject(id: string): Promise<{ project: Project }> {
	return (await apiClient(`/admin/projects/${id}`)) as { project: Project };
}

export async function createProject(data: {
	name: string;
	slug: string;
	default_ttl_hours?: number;
	max_inbox_count?: number;
}): Promise<{ project: Project }> {
	return (await apiClient('/admin/projects', {
		method: 'POST',
		body: JSON.stringify({ project: data })
	})) as { project: Project };
}

export async function updateProject(
	id: string,
	data: { name?: string; default_ttl_hours?: number; max_inbox_count?: number }
): Promise<{ project: Project }> {
	return (await apiClient(`/admin/projects/${id}`, {
		method: 'PATCH',
		body: JSON.stringify({ project: data })
	})) as { project: Project };
}

export async function deleteProject(id: string): Promise<void> {
	await apiClient(`/admin/projects/${id}`, { method: 'DELETE' });
}

export async function fetchApiKeys(
	projectId: string
): Promise<{ api_keys: ApiKey[] }> {
	return (await apiClient(`/admin/projects/${projectId}/api_keys`)) as {
		api_keys: ApiKey[];
	};
}

export async function createApiKey(
	projectId: string,
	label: string
): Promise<{ api_key: ApiKeyWithToken }> {
	return (await apiClient(`/admin/projects/${projectId}/api_keys`, {
		method: 'POST',
		body: JSON.stringify({ api_key: { label } })
	})) as { api_key: ApiKeyWithToken };
}

export async function deleteApiKey(id: string): Promise<void> {
	await apiClient(`/admin/api_keys/${id}`, { method: 'DELETE' });
}
