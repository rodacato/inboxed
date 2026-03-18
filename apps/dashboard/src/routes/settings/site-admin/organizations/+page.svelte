<script lang="ts">
	import {
		fetchSiteOrganizations,
		grantPermanent,
		deleteSiteOrganization
	} from '../../../../features/site-admin/site-admin.service';
	import type { SiteOrganization } from '../../../../features/site-admin/site-admin.types';

	let orgs = $state<SiteOrganization[]>([]);
	let loading = $state(true);

	$effect(() => {
		loadOrgs();
	});

	async function loadOrgs() {
		orgs = await fetchSiteOrganizations();
		loading = false;
	}

	async function handleGrantPermanent(org: SiteOrganization) {
		if (!confirm(`Grant permanent access to "${org.name}"?`)) return;
		await grantPermanent(org.id);
		await loadOrgs();
	}

	async function handleDelete(org: SiteOrganization) {
		if (!confirm(`Delete organization "${org.name}" and all its data? This cannot be undone.`)) return;
		await deleteSiteOrganization(org.id);
		orgs = orgs.filter((o) => o.id !== org.id);
	}

	function formatDate(iso: string): string {
		return new Date(iso).toLocaleDateString();
	}

	function trialStatus(org: SiteOrganization): { label: string; color: string } {
		if (org.permanent) return { label: 'Permanent', color: 'text-phosphor' };
		if (!org.trial) return { label: 'Permanent', color: 'text-phosphor' };
		const endsAt = org.trial_ends_at ? new Date(org.trial_ends_at) : null;
		if (endsAt && endsAt > new Date()) {
			const days = Math.ceil((endsAt.getTime() - Date.now()) / 86400000);
			return { label: `Trial (${days}d)`, color: 'text-amber' };
		}
		return { label: 'Expired', color: 'text-error' };
	}
</script>

<div class="p-8 max-w-4xl">
	<h1 class="text-2xl font-display font-bold text-text-primary mb-6">Organizations</h1>

	{#if loading}
		<p class="text-text-dim font-mono text-sm">Loading...</p>
	{:else if orgs.length === 0}
		<p class="text-text-dim font-mono text-sm">No organizations.</p>
	{:else}
		<table class="w-full text-sm">
			<thead>
				<tr class="border-b border-border text-left">
					<th class="py-2 pr-4 font-mono text-xs text-text-dim font-medium">Name</th>
					<th class="py-2 pr-4 font-mono text-xs text-text-dim font-medium">Status</th>
					<th class="py-2 pr-4 font-mono text-xs text-text-dim font-medium text-center">Members</th>
					<th class="py-2 pr-4 font-mono text-xs text-text-dim font-medium text-center">Projects</th>
					<th class="py-2 pr-4 font-mono text-xs text-text-dim font-medium">Created</th>
					<th class="py-2 font-mono text-xs text-text-dim font-medium text-right">Actions</th>
				</tr>
			</thead>
			<tbody>
				{#each orgs as org (org.id)}
					{@const status = trialStatus(org)}
					<tr class="border-b border-border/50 hover:bg-surface-2/50">
						<td class="py-3 pr-4">
							<p class="font-mono text-text-primary font-medium">{org.name}</p>
							<p class="font-mono text-[10px] text-text-dim">{org.slug}</p>
						</td>
						<td class="py-3 pr-4">
							<span class="font-mono text-xs font-medium {status.color}">{status.label}</span>
						</td>
						<td class="py-3 pr-4 text-center font-mono text-text-secondary">{org.member_count}</td>
						<td class="py-3 pr-4 text-center font-mono text-text-secondary">{org.project_count}</td>
						<td class="py-3 pr-4 font-mono text-xs text-text-dim">{formatDate(org.created_at)}</td>
						<td class="py-3 text-right">
							<div class="flex items-center justify-end gap-2">
								{#if !org.permanent && org.trial}
									<button
										onclick={() => handleGrantPermanent(org)}
										class="px-2 py-1 text-[10px] font-mono text-phosphor border border-phosphor/30 rounded hover:bg-phosphor/10 transition-colors"
									>
										Grant Permanent
									</button>
								{/if}
								<button
									onclick={() => handleDelete(org)}
									class="px-2 py-1 text-[10px] font-mono text-error border border-error/30 rounded hover:bg-error/10 transition-colors"
								>
									Delete
								</button>
							</div>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	{/if}
</div>
