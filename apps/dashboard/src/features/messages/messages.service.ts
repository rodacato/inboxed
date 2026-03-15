import { apiClient } from '$lib/api-client';
import type { Message } from './messages.types';

export async function fetchMessages(): Promise<Message[]> {
	// TODO: Replace with real API call when endpoint exists
	return [];
}

export async function fetchMessage(id: string): Promise<Message | null> {
	// TODO: Replace with real API call when endpoint exists
	void id;
	return null;
}
