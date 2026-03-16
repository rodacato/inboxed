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
	const res = await fetch(`${API_URL}${path}`, {
		...options,
		credentials: 'include',
		headers: {
			'Content-Type': 'application/json',
			...(options.headers || {})
		}
	});

	if (res.status === 401) {
		if (typeof window !== 'undefined' && !path.startsWith('/auth/') && window.location.pathname !== '/login') {
			window.location.href = '/login';
		}
		throw new ApiError(401, { error: 'Unauthorized' });
	}

	if (!res.ok) {
		const body = await res.json().catch(() => ({}));
		throw new ApiError(res.status, body);
	}

	if (res.status === 204) return null;

	return res.json();
}
