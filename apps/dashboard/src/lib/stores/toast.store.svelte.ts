export interface Toast {
	id: string;
	type: 'info' | 'success' | 'warning' | 'error';
	title: string;
	description?: string;
	action?: { label: string; href: string };
	duration?: number;
}

const MAX_VISIBLE = 3;

let toasts = $state<Toast[]>([]);
let queue: Omit<Toast, 'id'>[] = [];

function processQueue() {
	while (queue.length > 0 && toasts.length < MAX_VISIBLE) {
		const next = queue.shift()!;
		addToVisible(next);
	}
}

function addToVisible(toast: Omit<Toast, 'id'>) {
	const id = crypto.randomUUID();
	toasts = [...toasts, { ...toast, id }];
	const duration = toast.duration ?? 5000;
	if (duration > 0) {
		setTimeout(() => dismiss(id), duration);
	}
}

function dismiss(id: string) {
	toasts = toasts.filter((t) => t.id !== id);
	processQueue();
}

// Preference
function isEnabled(): boolean {
	if (typeof window === 'undefined') return true;
	return localStorage.getItem('inboxed_toasts_enabled') !== 'false';
}

function setEnabled(enabled: boolean) {
	localStorage.setItem('inboxed_toasts_enabled', String(enabled));
	if (!enabled) {
		toasts = [];
		queue = [];
	}
}

export const toastStore = {
	get items() {
		return toasts;
	},

	get enabled() {
		return isEnabled();
	},

	add(toast: Omit<Toast, 'id'>) {
		if (!isEnabled()) return;
		if (toasts.length >= MAX_VISIBLE) {
			queue.push(toast);
		} else {
			addToVisible(toast);
		}
	},

	dismiss,

	clear() {
		toasts = [];
		queue = [];
	},

	setEnabled
};
