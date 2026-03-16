import { apiClient, ApiError } from '$lib/api-client';
import { authStore, type AuthUser, type AuthOrganization } from '$lib/stores/auth.store.svelte';
import { mapOrganization } from '$lib/utils/map-organization';

interface LoginResponse {
	data: {
		id: string;
		email: string;
		role: string;
		site_admin: boolean;
		organization?: Record<string, unknown>;
	};
}

interface RegisterResponse {
	data: {
		id: string;
		email: string;
		verification_required: boolean;
	};
}

export async function login(email: string, password: string): Promise<{ user: AuthUser; organization: AuthOrganization | null }> {
	const res = (await apiClient('/auth/sessions', {
		method: 'POST',
		body: JSON.stringify({ email, password })
	})) as LoginResponse;

	const user: AuthUser = {
		id: res.data.id,
		email: res.data.email,
		role: res.data.role as AuthUser['role'],
		siteAdmin: res.data.site_admin
	};

	const organization = res.data.organization
		? mapOrganization(res.data.organization)
		: null;

	authStore.setAuthenticated(user, organization);
	return { user, organization };
}

export async function register(email: string, password: string, invitationToken?: string): Promise<{ verificationRequired: boolean }> {
	const body: Record<string, string> = { email, password };
	if (invitationToken) body.invitation_token = invitationToken;

	const res = (await apiClient('/auth/register', {
		method: 'POST',
		body: JSON.stringify(body)
	})) as RegisterResponse;

	return { verificationRequired: res.data.verification_required };
}

export async function setup(setupToken: string, orgName: string, email: string, password: string): Promise<void> {
	await apiClient('/setup', {
		method: 'POST',
		body: JSON.stringify({
			setup_token: setupToken,
			organization_name: orgName,
			email,
			password
		})
	});
}

export async function verifyEmail(token: string): Promise<boolean> {
	try {
		await apiClient(`/auth/verify?token=${encodeURIComponent(token)}`);
		return true;
	} catch {
		return false;
	}
}

export async function resendVerification(email: string): Promise<void> {
	await apiClient('/auth/resend-verification', {
		method: 'POST',
		body: JSON.stringify({ email })
	});
}

export async function forgotPassword(email: string): Promise<void> {
	await apiClient('/auth/forgot-password', {
		method: 'POST',
		body: JSON.stringify({ email })
	});
}

export async function resetPassword(token: string, password: string): Promise<void> {
	await apiClient('/auth/reset-password', {
		method: 'PUT',
		body: JSON.stringify({ token, password })
	});
}

export async function getInvitation(token: string): Promise<{ email: string; organization_name: string; role: string; expires_at: string }> {
	const res = (await apiClient(`/auth/invitation?token=${encodeURIComponent(token)}`)) as {
		invitation: { email: string; organization_name: string; role: string; expires_at: string };
	};
	return res.invitation;
}

export async function acceptInvitation(token: string, password: string): Promise<void> {
	await apiClient('/auth/accept-invitation', {
		method: 'POST',
		body: JSON.stringify({ token, password })
	});
}

export function getErrorMessage(err: unknown): string {
	if (err instanceof ApiError) {
		const body = err.body as Record<string, unknown>;
		if (body?.error === 'email_not_verified') return 'Please verify your email before logging in.';
		if (body?.error === 'invalid_credentials') return 'Invalid email or password.';
		if (body?.error === 'registration_closed') return 'Registration is currently closed.';
		if (body?.error === 'invitation_expired') return 'This invitation has expired.';
		if (body?.detail) return String(body.detail);
		if (body?.error) return String(body.error);
	}
	return 'An unexpected error occurred.';
}
