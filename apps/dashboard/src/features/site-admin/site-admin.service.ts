import { apiClient } from '$lib/api-client';
import type { SiteOrganization, SiteUser, SiteSettings, BlockedAddress } from './site-admin.types';

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

// Blocked addresses
export async function fetchBlockedAddresses(): Promise<BlockedAddress[]> {
	const res = (await apiClient('/site_admin/blocked_addresses')) as { data: BlockedAddress[] };
	return res.data;
}

export async function createBlockedAddress(address: string, reason?: string): Promise<{ data: BlockedAddress; deleted_inboxes: number }> {
	return (await apiClient('/site_admin/blocked_addresses', {
		method: 'POST',
		body: JSON.stringify({ address, reason })
	})) as { data: BlockedAddress; deleted_inboxes: number };
}

export async function deleteBlockedAddress(id: string): Promise<void> {
	await apiClient(`/site_admin/blocked_addresses/${id}`, { method: 'DELETE' });
}
