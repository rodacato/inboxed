import { apiClient } from '$lib/api-client';
import type { SiteOrganization, SiteUser, SiteSettings } from './site-admin.types';

export async function fetchSiteSettings(): Promise<SiteSettings> {
	const res = (await apiClient('/site_admin/settings')) as { data: SiteSettings };
	return res.data;
}

export async function fetchSiteOrganizations(): Promise<SiteOrganization[]> {
	const res = (await apiClient('/site_admin/organizations')) as { data: SiteOrganization[] };
	return res.data;
}

export async function grantPermanent(orgId: string): Promise<void> {
	await apiClient(`/site_admin/organizations/${orgId}/grant_permanent`, { method: 'POST' });
}

export async function deleteSiteOrganization(orgId: string): Promise<void> {
	await apiClient(`/site_admin/organizations/${orgId}`, { method: 'DELETE' });
}

export async function fetchSiteUsers(): Promise<SiteUser[]> {
	const res = (await apiClient('/site_admin/users')) as { data: SiteUser[] };
	return res.data;
}

export async function deleteSiteUser(userId: string): Promise<void> {
	await apiClient(`/site_admin/users/${userId}`, { method: 'DELETE' });
}
