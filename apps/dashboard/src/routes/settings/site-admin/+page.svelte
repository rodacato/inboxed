<script lang="ts">
	import { fetchSiteSettings } from '../../../features/site-admin/site-admin.service';
	import type { SiteSettings } from '../../../features/site-admin/site-admin.types';

	let settings = $state<SiteSettings | null>(null);
	let loading = $state(true);

	$effect(() => {
		fetchSiteSettings().then((res) => {
			settings = res;
			loading = false;
		});
	});
</script>

<div class="max-w-2xl mx-auto p-6">
	<h1 class="text-2xl font-display font-bold text-text-primary mb-6">Site Administration</h1>

	{#if loading}
		<p class="text-text-dim font-mono text-sm">Loading...</p>
	{:else if settings}
		<div class="grid grid-cols-2 gap-4 mb-8">
			<div class="p-4 rounded-lg bg-surface-2 border border-border">
				<p class="text-2xl font-display font-bold text-phosphor">{settings.user_count}</p>
				<p class="text-xs font-mono text-text-dim">Users</p>
			</div>
			<div class="p-4 rounded-lg bg-surface-2 border border-border">
				<p class="text-2xl font-display font-bold text-phosphor">{settings.organization_count}</p>
				<p class="text-xs font-mono text-text-dim">Organizations</p>
			</div>
		</div>

		<h2 class="text-sm font-mono font-bold text-text-primary mb-3">Configuration</h2>
		<div class="space-y-2">
			<div class="flex justify-between items-center px-4 py-3 rounded-lg bg-surface-2 border border-border">
				<span class="text-xs font-mono text-text-secondary">Registration Mode</span>
				<span class="text-xs font-mono font-medium text-text-primary">{settings.registration_mode}</span>
			</div>
			<div class="flex justify-between items-center px-4 py-3 rounded-lg bg-surface-2 border border-border">
				<span class="text-xs font-mono text-text-secondary">Trial Duration</span>
				<span class="text-xs font-mono font-medium text-text-primary">{settings.trial_duration_days} days</span>
			</div>
			<div class="flex justify-between items-center px-4 py-3 rounded-lg bg-surface-2 border border-border">
				<span class="text-xs font-mono text-text-secondary">Outbound SMTP</span>
				<span class="text-xs font-mono font-medium {settings.outbound_smtp_configured ? 'text-phosphor' : 'text-text-dim'}">
					{settings.outbound_smtp_configured ? 'Configured' : 'Not configured'}
				</span>
			</div>
			<div class="flex justify-between items-center px-4 py-3 rounded-lg bg-surface-2 border border-border">
				<span class="text-xs font-mono text-text-secondary">GitHub OAuth</span>
				<span class="text-xs font-mono font-medium {settings.github_oauth_configured ? 'text-phosphor' : 'text-text-dim'}">
					{settings.github_oauth_configured ? 'Configured' : 'Not configured'}
				</span>
			</div>
		</div>
	{/if}
</div>
