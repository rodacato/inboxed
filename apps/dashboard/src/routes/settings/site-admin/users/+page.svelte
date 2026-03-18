<script lang="ts">
	import { fetchSiteUsers, deleteSiteUser } from '../../../../features/site-admin/site-admin.service';
	import type { SiteUser } from '../../../../features/site-admin/site-admin.types';
	import { authStore } from '$lib/stores/auth.store.svelte';

	let users = $state<SiteUser[]>([]);
	let loading = $state(true);

	$effect(() => {
		fetchSiteUsers().then((res) => {
			users = res;
			loading = false;
		});
	});

	async function handleDelete(user: SiteUser) {
		if (!confirm(`Delete user "${user.email}"? This cannot be undone.`)) return;
		await deleteSiteUser(user.id);
		users = users.filter((u) => u.id !== user.id);
	}

	function formatDate(iso: string | null): string {
		if (!iso) return 'Never';
		return new Date(iso).toLocaleDateString();
	}
</script>

<div class="max-w-4xl mx-auto p-6">
	<h1 class="text-2xl font-display font-bold text-text-primary mb-6">Users</h1>

	{#if loading}
		<p class="text-text-dim font-mono text-sm">Loading...</p>
	{:else if users.length === 0}
		<p class="text-text-dim font-mono text-sm">No users.</p>
	{:else}
		<table class="w-full text-sm">
			<thead>
				<tr class="border-b border-border text-left">
					<th class="py-2 pr-4 font-mono text-xs text-text-dim font-medium">Email</th>
					<th class="py-2 pr-4 font-mono text-xs text-text-dim font-medium">Organization</th>
					<th class="py-2 pr-4 font-mono text-xs text-text-dim font-medium">Role</th>
					<th class="py-2 pr-4 font-mono text-xs text-text-dim font-medium">Last Login</th>
					<th class="py-2 font-mono text-xs text-text-dim font-medium text-right">Actions</th>
				</tr>
			</thead>
			<tbody>
				{#each users as user (user.id)}
					<tr class="border-b border-border/50 hover:bg-surface-2/50">
						<td class="py-3 pr-4">
							<div class="flex items-center gap-2">
								<span class="font-mono text-text-primary">{user.email}</span>
								{#if !user.verified}
									<span class="px-1.5 py-0 rounded text-[9px] font-mono font-medium bg-amber/15 text-amber">Unverified</span>
								{/if}
							</div>
						</td>
						<td class="py-3 pr-4 font-mono text-text-secondary">{user.organization ?? '—'}</td>
						<td class="py-3 pr-4">
							{#if user.site_admin}
								<span class="px-1.5 py-0 rounded text-[9px] font-mono font-medium bg-phosphor/15 text-phosphor">Site Admin</span>
							{:else}
								<span class="font-mono text-xs text-text-dim">User</span>
							{/if}
						</td>
						<td class="py-3 pr-4 font-mono text-xs text-text-dim">{formatDate(user.last_sign_in_at)}</td>
						<td class="py-3 text-right">
							{#if user.id !== authStore.user?.id}
								<button
									onclick={() => handleDelete(user)}
									class="px-2 py-1 text-[10px] font-mono text-error border border-error/30 rounded hover:bg-error/10 transition-colors"
								>
									Delete
								</button>
							{/if}
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	{/if}
</div>
