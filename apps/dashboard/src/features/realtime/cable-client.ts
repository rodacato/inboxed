export interface CableMessage {
	type: string;
	[key: string]: unknown;
}

export function createCable() {
	const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
	const host = window.location.host;
	const url = `${protocol}//${host}/cable`;

	let ws: WebSocket | null = null;
	let reconnectAttempts = 0;
	const maxReconnectAttempts = 10;
	const subscriptions = new Map<string, (msg: CableMessage) => void>();
	let onConnectCb: (() => void) | null = null;
	let onDisconnectCb: (() => void) | null = null;

	function connect() {
		ws = new WebSocket(url);

		ws.onopen = () => {
			reconnectAttempts = 0;
			onConnectCb?.();
			for (const [identifier] of subscriptions) {
				ws!.send(JSON.stringify({ command: 'subscribe', identifier }));
			}
		};

		ws.onmessage = (event) => {
			const data = JSON.parse(event.data);
			if (data.type === 'ping' || data.type === 'welcome' || data.type === 'confirm_subscription')
				return;
			if (data.identifier && data.message) {
				const handler = subscriptions.get(data.identifier);
				handler?.(data.message);
			}
		};

		ws.onclose = () => {
			onDisconnectCb?.();
			scheduleReconnect();
		};
	}

	function scheduleReconnect() {
		if (reconnectAttempts >= maxReconnectAttempts) return;
		const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000);
		reconnectAttempts++;
		setTimeout(connect, delay);
	}

	function subscribe(
		channel: string,
		params: Record<string, string>,
		handler: (msg: CableMessage) => void
	): () => void {
		const identifier = JSON.stringify({ channel, ...params });
		subscriptions.set(identifier, handler);
		if (ws?.readyState === WebSocket.OPEN) {
			ws.send(JSON.stringify({ command: 'subscribe', identifier }));
		}
		return () => {
			subscriptions.delete(identifier);
			if (ws?.readyState === WebSocket.OPEN) {
				ws.send(JSON.stringify({ command: 'unsubscribe', identifier }));
			}
		};
	}

	function disconnect() {
		subscriptions.clear();
		reconnectAttempts = maxReconnectAttempts; // prevent reconnect
		ws?.close();
		ws = null;
	}

	function onConnect(cb: () => void) {
		onConnectCb = cb;
	}
	function onDisconnect(cb: () => void) {
		onDisconnectCb = cb;
	}

	connect();

	return { subscribe, disconnect, onConnect, onDisconnect };
}
