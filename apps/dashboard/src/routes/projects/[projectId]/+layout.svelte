<script lang="ts">
	import { page } from '$app/stores';
	import { getEnabledModules } from '$lib/config/modules';
	import { authStore } from '$lib/stores/auth.store.svelte';

	let { children } = $props();
	const projectId = $derived($page.params.projectId ?? '');
	const modules = $derived(getEnabledModules(authStore.features));

	const tabs = $derived([
		...modules.map((m) => ({
			id: m.id,
			label: m.label,
			href: m.route(projectId),
			icon: m.icon
		})),
		{
			id: 'settings',
			label: 'Settings',
			href: `/projects/${projectId}/settings`,
			icon: 'settings'
		}
	]);

	function isActive(href: string): boolean {
		const path = $page.url.pathname;
		if (href.endsWith('/settings')) return path.startsWith(href);
		// For modules, match the module prefix
		return path.startsWith(href);
	}
</script>

<div class="flex flex-col h-full overflow-hidden">
	<!-- Module tab bar -->
	<nav class="flex border-b border-border bg-surface px-4 shrink-0 overflow-x-auto">
		{#each tabs as tab (tab.id)}
			<a
				href={tab.href}
				class="flex items-center gap-1.5 px-4 py-3 font-mono text-xs border-b-2 transition-colors whitespace-nowrap
					{isActive(tab.href)
					? 'border-phosphor text-phosphor'
					: 'border-transparent text-text-secondary hover:text-text-primary'}"
			>
				<span class="material-symbols-outlined text-base">{tab.icon}</span>
				{tab.label}
			</a>
		{/each}
	</nav>

	<!-- Module content -->
	<div class="flex-1 overflow-hidden">
		{@render children()}
	</div>
</div>
