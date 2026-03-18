<script lang="ts">
	import { page } from '$app/stores';
	import { authStore } from '$lib/stores/auth.store.svelte';

	let { children } = $props();

	const isAdmin = $derived(authStore.isOrgAdmin);
	const isSiteAdmin = $derived(authStore.isSiteAdmin);

	interface NavItem {
		href: string;
		label: string;
		icon: string;
		adminOnly?: boolean;
		siteAdminOnly?: boolean;
	}

	const navItems: NavItem[] = [
		{ href: '/settings/profile', label: 'Profile', icon: 'person' },
		{ href: '/settings/appearance', label: 'Appearance', icon: 'palette' },
		{ href: '/settings/organization', label: 'Organization', icon: 'domain', adminOnly: true },
		{ href: '/settings/projects', label: 'Projects', icon: 'folder_open', adminOnly: true },
		{ href: '/settings/members', label: 'Members', icon: 'group', adminOnly: true },
	];

	const siteAdminItems: NavItem[] = [
		{ href: '/settings/site-admin', label: 'Overview', icon: 'dashboard', siteAdminOnly: true },
		{ href: '/settings/site-admin/organizations', label: 'Organizations', icon: 'domain_add', siteAdminOnly: true },
		{ href: '/settings/site-admin/users', label: 'Users', icon: 'manage_accounts', siteAdminOnly: true },
	];

	const visibleItems = $derived(navItems.filter((item) => !item.adminOnly || isAdmin));

	function isActive(href: string): boolean {
		return $page.url.pathname === href || $page.url.pathname.startsWith(href + '/');
	}
</script>

<div class="flex h-full overflow-hidden">
	<!-- Settings sidebar -->
	<nav class="w-56 shrink-0 border-r border-border bg-surface overflow-y-auto p-4">
		<a
			href="/projects"
			class="flex items-center gap-2 px-3 mb-4 group"
		>
			<span class="material-symbols-outlined text-base text-text-dim group-hover:text-text-primary transition-colors">arrow_back</span>
			<h2 class="text-sm font-display font-bold text-text-primary">Settings</h2>
		</a>

		<!-- User-scoped -->
		<div class="mb-4">
			<p class="text-[10px] font-mono font-bold uppercase tracking-widest text-text-dim px-3 mb-1">Account</p>
			{#each visibleItems.filter((i) => !i.adminOnly) as item (item.href)}
				<a
					href={item.href}
					class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm font-mono transition-colors
						{isActive(item.href)
						? 'bg-phosphor-glow text-phosphor font-medium'
						: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary'}"
				>
					<span class="material-symbols-outlined text-base">{item.icon}</span>
					{item.label}
				</a>
			{/each}
		</div>

		<!-- Org-scoped (admin) -->
		{#if isAdmin}
			<div>
				<p class="text-[10px] font-mono font-bold uppercase tracking-widest text-text-dim px-3 mb-1">Admin</p>
				{#each visibleItems.filter((i) => i.adminOnly) as item (item.href)}
					<a
						href={item.href}
						class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm font-mono transition-colors
							{isActive(item.href)
							? 'bg-phosphor-glow text-phosphor font-medium'
							: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary'}"
					>
						<span class="material-symbols-outlined text-base">{item.icon}</span>
						{item.label}
					</a>
				{/each}
			</div>
		{/if}

		<!-- Site admin -->
		{#if isSiteAdmin}
			<div class="mt-4">
				<p class="text-[10px] font-mono font-bold uppercase tracking-widest text-text-dim px-3 mb-1">Site Admin</p>
				{#each siteAdminItems as item (item.href)}
					<a
						href={item.href}
						class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm font-mono transition-colors
							{isActive(item.href)
							? 'bg-phosphor-glow text-phosphor font-medium'
							: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary'}"
					>
						<span class="material-symbols-outlined text-base">{item.icon}</span>
						{item.label}
					</a>
				{/each}
			</div>
		{/if}
	</nav>

	<!-- Settings content -->
	<div class="flex-1 overflow-y-auto">
		{@render children()}
	</div>
</div>
