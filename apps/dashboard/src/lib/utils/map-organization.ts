import type { AuthOrganization } from '$lib/stores/auth.store.svelte';

export function mapOrganization(org: Record<string, unknown>): AuthOrganization {
	const trialEndsAt = org.trial_ends_at as string | null;
	const trial = org.trial as boolean;
	let daysRemaining: number | null = null;
	let trialActive = false;

	if (trial && trialEndsAt) {
		const diff = new Date(trialEndsAt).getTime() - Date.now();
		daysRemaining = Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
		trialActive = diff > 0;
	} else if (!trial) {
		trialActive = true; // permanent
	}

	return {
		id: org.id as string,
		name: org.name as string,
		slug: org.slug as string,
		trial,
		trialEndsAt,
		trialActive,
		daysRemaining
	};
}
