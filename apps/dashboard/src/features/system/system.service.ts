import { apiClient } from '$lib/api-client';
import type { ConnectionStatus, SystemStatus } from './system.types';

export async function checkApiStatus(): Promise<ConnectionStatus> {
	try {
		const res = (await apiClient('/admin/status')) as SystemStatus;
		return res.status === 'ok' ? 'connected' : 'error';
	} catch {
		return 'disconnected';
	}
}
