<script lang="ts">
	import { authStore } from '$lib/stores/auth.store.svelte';

	let dismissed = $state(false);

	const org = $derived(authStore.organization);
	const expired = $derived(org?.trial && !org?.trialActive);
	const daysLeft = $derived(org?.daysRemaining ?? 0);
	const endsAt = $derived(
		org?.trialEndsAt
			? new Date(org.trialEndsAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
			: null
	);
</script>

{#if org?.trial && !dismissed}
	<div
		class="px-4 py-2 text-xs font-mono flex items-center gap-3 shrink-0
			{expired
				? 'bg-error/10 border-b border-error/20 text-error'
				: 'bg-amber/10 border-b border-amber/20 text-amber'}"
	>
		<span class="material-symbols-outlined text-sm">
			{expired ? 'block' : 'timer'}
		</span>

		{#if expired}
			<span class="flex-1">
				Your trial has expired. You can still view existing data. Contact the administrator to continue using Inboxed.
			</span>
		{:else}
			<span class="flex-1">
				Trial: {daysLeft} day{daysLeft !== 1 ? 's' : ''} remaining{endsAt ? ` (ends ${endsAt})` : ''}.
				Contact the administrator for permanent access.
			</span>
			<button
				onclick={() => (dismissed = true)}
				class="text-text-dim hover:text-text-secondary transition-colors"
			>
				<span class="material-symbols-outlined text-sm">close</span>
			</button>
		{/if}
	</div>
{/if}
