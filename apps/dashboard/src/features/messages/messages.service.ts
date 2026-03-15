import { apiClient } from '$lib/api-client';
import type { Message } from './messages.types';

export async function fetchMessages(): Promise<Message[]> {
	return (await apiClient('/api/v1/messages')) as Message[];
}

export async function fetchMessage(id: string): Promise<Message> {
	return (await apiClient(`/api/v1/messages/${id}`)) as Message;
}
