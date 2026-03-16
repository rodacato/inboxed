<script lang="ts">
	import { authStore } from '$lib/stores/auth.store.svelte';

	const user = $derived(authStore.user);
	const org = $derived(authStore.organization);

	function roleLabel(role: string): string {
		switch (role) {
			case 'site_admin': return 'Site Admin';
			case 'org_admin': return 'Admin';
			default: return 'Member';
		}
	}
</script>

<div class="max-w-xl mx-auto p-6">
	<h1 class="text-xl font-display font-bold text-text-primary mb-6">Profile</h1>

	{#if user}
		<div class="bg-surface border border-border rounded-lg p-6 space-y-6">
			<!-- Email -->
			<div>
				<label class="block mb-2 text-xs font-mono text-text-dim uppercase tracking-widest">
					Email
				</label>
				<p class="font-mono text-sm text-text-primary">{user.email}</p>
			</div>

			<!-- Role -->
			<div>
				<label class="block mb-2 text-xs font-mono text-text-dim uppercase tracking-widest">
					Role
				</label>
				<span class="inline-block text-xs font-mono text-text-primary bg-surface-2 rounded px-2.5 py-1 border border-border">
					{roleLabel(user.role)}
				</span>
			</div>

			<!-- Organization -->
			{#if org}
				<div>
					<label class="block mb-2 text-xs font-mono text-text-dim uppercase tracking-widest">
						Organization
					</label>
					<p class="font-mono text-sm text-text-primary">{org.name}</p>
				</div>
			{/if}
		</div>
	{/if}
</div>
