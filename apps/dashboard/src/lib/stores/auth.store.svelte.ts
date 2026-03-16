import { apiClient } from '$lib/api-client';
import { mapOrganization } from '$lib/utils/map-organization';

export interface AuthUser {
	id: string;
	email: string;
	role: 'site_admin' | 'org_admin' | 'member';
	siteAdmin: boolean;
}

export interface AuthOrganization {
	id: string;
	name: string;
	slug: string;
	trial: boolean;
	trialEndsAt: string | null;
	trialActive: boolean;
	daysRemaining: number | null;
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
	user: AuthUser | null;
	organization: AuthOrganization | null;
	features: AppFeatures;
	setupRequired: boolean;
	registrationMode: string;
	outboundSmtpConfigured: boolean;
	loading: boolean;
}

const DEFAULT_FEATURES: AppFeatures = {
	mail: true,
	hooks: false,
	forms: false,
	heartbeats: false,
	mcp: true
};

let state = $state<AuthState>({
	isAuthenticated: false,
	user: null,
	organization: null,
	features: { ...DEFAULT_FEATURES },
	setupRequired: false,
	registrationMode: 'closed',
	outboundSmtpConfigured: false,
	loading: true
});

function mapUser(raw: { id: string; email: string; role: string; site_admin: boolean }): AuthUser {
	return {
		id: raw.id,
		email: raw.email,
		role: raw.role as AuthUser['role'],
		siteAdmin: raw.site_admin
	};
}

export const authStore = {
	get isAuthenticated() {
		return state.isAuthenticated;
	},

	get user() {
		return state.user;
	},

	get organization() {
		return state.organization;
	},

	get features() {
		return state.features;
	},

	get setupRequired() {
		return state.setupRequired;
	},

	get registrationMode() {
		return state.registrationMode;
	},

	get outboundSmtpConfigured() {
		return state.outboundSmtpConfigured;
	},

	get loading() {
		return state.loading;
	},

	get isOrgAdmin() {
		return state.user?.role === 'org_admin' || state.user?.role === 'site_admin';
	},

	get isSiteAdmin() {
		return state.user?.siteAdmin ?? false;
	},

	get trialExpired() {
		const org = state.organization;
		if (!org || !org.trial) return false;
		return !org.trialActive;
	},

	async checkSession(): Promise<boolean> {
		try {
			const res = (await apiClient('/auth/me')) as {
				data: {
					id: string;
					email: string;
					role: string;
					site_admin: boolean;
					organization?: Record<string, unknown>;
				};
			};

			state = {
				...state,
				isAuthenticated: true,
				user: mapUser(res.data),
				organization: res.data.organization
					? mapOrganization(res.data.organization)
					: null,
				loading: false
			};
			return true;
		} catch {
			state = { ...state, isAuthenticated: false, user: null, organization: null, loading: false };
			return false;
		}
	},

	async loadStatus() {
		try {
			const res = (await apiClient('/admin/status')) as {
				setup_completed?: boolean;
				registration_mode?: string;
				outbound_smtp_configured?: boolean;
				features?: Record<string, boolean>;
				user?: {
					id: string;
					email: string;
					role: string;
					site_admin: boolean;
				};
				organization?: Record<string, unknown>;
			};

			state = {
				...state,
				setupRequired: res.setup_completed === false,
				registrationMode: res.registration_mode ?? 'closed',
				outboundSmtpConfigured: res.outbound_smtp_configured ?? false,
				features: { ...DEFAULT_FEATURES, ...(res.features ?? {}) },
				user: res.user ? mapUser(res.user) : state.user,
				organization: res.organization
					? mapOrganization(res.organization)
					: state.organization,
				isAuthenticated: !!res.user,
				loading: false
			};
		} catch {
			state = { ...state, loading: false };
		}
	},

	setAuthenticated(user: AuthUser, organization: AuthOrganization | null) {
		state = { ...state, isAuthenticated: true, user, organization };
	},

	async logout() {
		try {
			await apiClient('/auth/sessions', { method: 'DELETE' });
		} catch {
			// ignore
		}
		state = { ...state, isAuthenticated: false, user: null, organization: null };
		if (typeof window !== 'undefined') {
			window.location.href = '/login';
		}
	}
};
