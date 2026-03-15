import { createCable, type CableMessage } from './cable-client';
import { getStoredToken } from '$lib/api-client';

let cable: ReturnType<typeof createCable> | null = null;
let connected = $state(false);

export function getRealtimeStore() {
	return {
		get connected() {
			return connected;
		},

		connect() {
			const token = getStoredToken();
			if (!token || cable) return;

			cable = createCable(token);
			cable.onConnect(() => {
				connected = true;
			});
			cable.onDisconnect(() => {
				connected = false;
			});
		},

		subscribeToInbox(inboxId: string, handler: (msg: CableMessage) => void): () => void {
			if (!cable) return () => {};
			return cable.subscribe('InboxChannel', { inbox_id: inboxId }, handler);
		},

		subscribeToProject(projectId: string, handler: (msg: CableMessage) => void): () => void {
			if (!cable) return () => {};
			return cable.subscribe('ProjectChannel', { project_id: projectId }, handler);
		},

		disconnect() {
			cable?.disconnect();
			cable = null;
			connected = false;
		}
	};
}
