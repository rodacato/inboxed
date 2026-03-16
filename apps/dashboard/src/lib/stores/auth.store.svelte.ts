import { apiClient } from '$lib/api-client';

export interface AuthUser {
	id: string;
	email: string;
	verified: boolean;
}

export interface AppFeatures {
	mail: boolean;
	hooks: boolean;
	forms: boolean;
	heartbeats: boolean;
	mcp: boolean;
	[key: string]: boolean;
}

interface AuthState {
	isAuthenticated: boolean;
	mode: 'standalone' | 'cloud';
	token: string | null;
	user?: AuthUser;
	features: AppFeatures;
}

const DEFAULT_FEATURES: AppFeatures = {
	mail: true,
	hooks: false,
	forms: false,
	heartbeats: false,
	mcp: true
};

let state = $state<AuthState>({
	isAuthenticated: hasStoredToken(),
	mode: 'standalone',
	token: getToken(),
	features: { ...DEFAULT_FEATURES }
});

function hasStoredToken(): boolean {
	if (typeof window === 'undefined') return false;
	return !!localStorage.getItem('inboxed_admin_token');
}

function getToken(): string | null {
	if (typeof window === 'undefined') return null;
	return localStorage.getItem('inboxed_admin_token');
}

export const authStore = {
	get isAuthenticated() {
		return state.isAuthenticated;
	},

	get mode() {
		return state.mode;
	},

	get token() {
		return state.token;
	},

	get user() {
		return state.user;
	},

	get features() {
		return state.features;
	},

	get canManageAllProjects() {
		return state.mode === 'standalone';
	},

	setToken(token: string) {
		localStorage.setItem('inboxed_admin_token', token);
		state = { ...state, isAuthenticated: true, token };
	},

	clearToken() {
		localStorage.removeItem('inboxed_admin_token');
		state = { ...state, isAuthenticated: false, token: null, user: undefined };
	},

	async loadStatus() {
		try {
			const res = (await apiClient('/admin/status')) as {
				status: string;
				mode?: string;
				features?: Record<string, boolean>;
			};
			state = {
				...state,
				mode: (res.mode as 'standalone' | 'cloud') ?? 'standalone',
				features: { ...DEFAULT_FEATURES, ...(res.features ?? {}) }
			};
		} catch {
			// Keep defaults if status endpoint doesn't return mode/features yet
		}
	},

	logout() {
		this.clearToken();
		if (typeof window !== 'undefined') {
			window.location.href = '/login';
		}
	}
};
