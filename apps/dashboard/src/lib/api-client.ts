const API_URL = import.meta.env.VITE_API_URL || '';

export class ApiError extends Error {
	status: number;
	body: unknown;

	constructor(status: number, body: unknown) {
		super(`API error ${status}`);
		this.status = status;
		this.body = body;
	}
}

export async function apiClient(path: string, options: RequestInit = {}): Promise<unknown> {
	const token = getStoredToken();

	const res = await fetch(`${API_URL}${path}`, {
		...options,
		headers: {
			'Content-Type': 'application/json',
			...(token ? { Authorization: `Bearer ${token}` } : {}),
			...(options.headers || {})
		}
	});

	if (res.status === 401) {
		clearStoredToken();
		if (typeof window !== 'undefined') {
			window.location.href = '/login';
		}
		throw new ApiError(401, { error: 'Unauthorized' });
	}

	if (!res.ok) {
		const body = await res.json().catch(() => ({}));
		throw new ApiError(res.status, body);
	}

	return res.json();
}

// These functions are kept for backward compatibility and used by authStore internally.
// New code should use authStore instead of calling these directly.
export function getStoredToken(): string | null {
	if (typeof window === 'undefined') return null;
	return localStorage.getItem('inboxed_admin_token');
}

export function clearStoredToken(): void {
	if (typeof window === 'undefined') return;
	localStorage.removeItem('inboxed_admin_token');
}

export function setStoredToken(token: string): void {
	localStorage.setItem('inboxed_admin_token', token);
}

export function isAuthenticated(): boolean {
	return !!getStoredToken();
}
