import { createCable, type CableMessage } from './cable-client';

let cable: ReturnType<typeof createCable> | null = null;
let connected = $state(false);

export function getRealtimeStore() {
	return {
		get connected() {
			return connected;
		},

		connect() {
			if (cable) return;

			cable = createCable();
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
