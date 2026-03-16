export interface SetupResult {
	project: { id: string; name: string; slug: string };
	apiKey: { id: string; token: string; tokenPrefix: string; label: string };
	smtp: { host: string; port: number };
}

let data = $state<SetupResult | null>(null);

export const onboardingStore = {
	get data() {
		return data;
	},

	set(result: SetupResult) {
		data = result;
		if (typeof sessionStorage !== 'undefined') {
			sessionStorage.setItem('inboxed_setup_result', JSON.stringify(result));
		}
	},

	load(): SetupResult | null {
		if (data) return data;
		if (typeof sessionStorage !== 'undefined') {
			const stored = sessionStorage.getItem('inboxed_setup_result');
			if (stored) {
				data = JSON.parse(stored);
				return data;
			}
		}
		return null;
	},

	clear() {
		data = null;
		if (typeof sessionStorage !== 'undefined') {
			sessionStorage.removeItem('inboxed_setup_result');
		}
	}
};
