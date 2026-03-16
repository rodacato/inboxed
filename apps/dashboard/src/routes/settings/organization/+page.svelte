<script lang="ts">
	import { onMount } from 'svelte';
	import { apiClient } from '$lib/api-client';
	import { authStore } from '$lib/stores/auth.store.svelte';

	let orgName = $state('');
	let saving = $state(false);
	let saved = $state(false);
	let error = $state('');

	const isAdmin = $derived(authStore.isOrgAdmin);

	onMount(async () => {
		try {
			const res = (await apiClient('/admin/organization')) as { data: { name: string } };
			orgName = res.data.name;
		} catch {
			// ignore
		}
	});

	async function handleSave() {
		if (!orgName.trim()) return;
		saving = true;
		error = '';
		saved = false;

		try {
			await apiClient('/admin/organization', {
				method: 'PATCH',
				body: JSON.stringify({ organization: { name: orgName } })
			});
			saved = true;
			// Reload status to refresh org name in sidebar
			authStore.loadStatus();
			setTimeout(() => { saved = false; }, 2000);
		} catch {
			error = 'Failed to update organization.';
		} finally {
			saving = false;
		}
	}
</script>

<div class="h-full overflow-y-auto">
	<div class="max-w-xl mx-auto p-6">
		<h1 class="text-xl font-display font-bold text-text-primary mb-6">Organization</h1>

		<div class="bg-surface border border-border rounded-lg p-6">
			<form onsubmit={e => { e.preventDefault(); handleSave(); }}>
				<label class="block mb-2 text-xs font-mono text-text-dim uppercase tracking-widest" for="org-name">
					Name
				</label>
				<input
					id="org-name"
					type="text"
					bind:value={orgName}
					disabled={!isAdmin}
					class="w-full bg-base border border-border rounded px-4 py-3 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30 disabled:opacity-50"
				/>

				{#if error}
					<p class="text-error text-xs font-mono mt-2">{error}</p>
				{/if}
				{#if saved}
					<p class="text-phosphor text-xs font-mono mt-2">Saved.</p>
				{/if}

				{#if isAdmin}
					<button
						type="submit"
						disabled={saving || !orgName.trim()}
						class="mt-4 bg-phosphor text-base font-mono font-bold px-6 py-2 rounded text-sm hover:brightness-110 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
					>
						{saving ? 'Saving...' : 'Save'}
					</button>
				{/if}
			</form>

			<!-- Trial info -->
			{#if authStore.organization}
				<div class="mt-6 pt-6 border-t border-border">
					<h2 class="text-sm font-display font-bold text-text-primary mb-3">Plan</h2>
					{#if authStore.organization.trial}
						{#if authStore.organization.trialActive}
							<p class="text-sm font-mono text-text-secondary">
								Trial &mdash; {authStore.organization.daysRemaining} days remaining
							</p>
						{:else}
							<p class="text-sm font-mono text-error">
								Trial expired
							</p>
						{/if}
					{:else}
						<p class="text-sm font-mono text-phosphor">Permanent access</p>
					{/if}
				</div>
			{/if}
		</div>
	</div>
</div>
