<script lang="ts">
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { getTheme } from '$lib/theme.svelte';
	import { authStore } from '$lib/stores/auth.store.svelte';
	import { commandStore } from '$lib/stores/commands.store.svelte';
	import { toastStore } from '$lib/stores/toast.store.svelte';
	import { getEnabledModules } from '$lib/config/modules';
	import { projectsStore } from '$lib/stores/projects.store.svelte';
	import type { Project } from '../../features/projects/projects.types';

	let {
		wsConnected = false,
		collapsed = false,
		onNavigate
	}: { wsConnected?: boolean; collapsed?: boolean; onNavigate?: () => void } = $props();

	const theme = getTheme();
	const modules = $derived(getEnabledModules(authStore.features));

	const projects = $derived(projectsStore.projects);

	onMount(async () => {
		try {
			const loaded = await projectsStore.load();
			registerCommands(loaded);
		} catch {
			// ignore
		}
	});

	function registerCommands(projs: Project[]) {
		// Register project navigation commands
		commandStore.unregisterByPrefix('goto-project-');
		commandStore.registerMany(
			projs.map((p) => ({
				id: `goto-project-${p.id}`,
				label: `Go to "${p.name}" Mail`,
				category: 'navigation' as const,
				icon: 'folder',
				keywords: [p.name, p.slug],
				execute: () => {
					goto(`/projects/${p.id}/mail`);
					onNavigate?.();
				}
			}))
		);

		// Static commands
		commandStore.register({
			id: 'goto-search',
			label: 'Search emails',
			category: 'navigation',
			icon: 'search',
			keywords: ['find', 'query'],
			execute: () => {
				goto('/search');
				onNavigate?.();
			}
		});
		commandStore.register({
			id: 'goto-projects',
			label: 'Manage projects',
			category: 'navigation',
			icon: 'folder_open',
			keywords: ['projects', 'list'],
			execute: () => {
				goto('/projects');
				onNavigate?.();
			}
		});
		commandStore.register({
			id: 'action-new-project',
			label: 'Create new project',
			category: 'action',
			icon: 'add',
			keywords: ['new', 'create'],
			execute: () => {
				goto('/projects');
				onNavigate?.();
			}
		});
		commandStore.register({
			id: 'action-toggle-theme',
			label: theme.isDark ? 'Switch to light mode' : 'Switch to dark mode',
			category: 'action',
			icon: theme.isDark ? 'light_mode' : 'dark_mode',
			keywords: ['theme', 'dark', 'light'],
			execute: () => theme.toggle()
		});
		commandStore.register({
			id: 'action-toggle-toasts',
			label: toastStore.enabled ? 'Disable notifications' : 'Enable notifications',
			category: 'action',
			icon: toastStore.enabled ? 'notifications_off' : 'notifications',
			keywords: ['notifications', 'toast'],
			execute: () => toastStore.setEnabled(!toastStore.enabled)
		});
	}

	function logout() {
		authStore.logout();
	}

	function isModuleActive(href: string): boolean {
		return $page.url.pathname.startsWith(href);
	}

	const isMac = typeof navigator !== 'undefined' && navigator.platform?.includes('Mac');
	const orgName = $derived(authStore.organization?.name ?? 'Organization');
	const userEmail = $derived(authStore.user?.email ?? '');
	const userName = $derived(userEmail.split('@')[0] || 'User');
	const trialDaysLeft = $derived(authStore.organization?.daysRemaining);
	const isTrial = $derived(authStore.organization?.trial ?? false);
	const trialActive = $derived(authStore.organization?.trialActive ?? true);
	const isSettingsActive = $derived($page.url.pathname.startsWith('/settings'));
</script>

<aside
	class="flex flex-col border-r border-border bg-surface shrink-0 h-full transition-all
		{collapsed ? 'w-14' : 'w-60'}"
>
	<div class="p-4 flex-1 overflow-y-auto {collapsed ? 'px-2' : 'px-5'}">
		<!-- Logo -->
		<a href="/projects" class="flex items-center gap-3 mb-5" onclick={() => onNavigate?.()}>
			<div
				class="size-7 bg-phosphor rounded-lg flex items-center justify-center text-base shrink-0"
			>
				<span class="material-symbols-outlined text-lg">alternate_email</span>
			</div>
			{#if !collapsed}
				<h1 class="font-display font-bold text-lg tracking-tight text-text-primary">Inboxed</h1>
			{/if}
		</a>

		<nav class="space-y-0.5">
			<!-- Search -->
			<a
				href="/search"
				onclick={() => onNavigate?.()}
				class="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors
					{$page.url.pathname.startsWith('/search')
					? 'bg-phosphor-glow text-phosphor font-medium'
					: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary'}"
			>
				<span class="material-symbols-outlined text-lg">search</span>
				{#if !collapsed}
					<span class="flex-1">Search</span>
					<kbd class="text-[9px] font-mono text-text-dim bg-surface-2 rounded px-1 py-0.5 border border-border">
						{isMac ? '⌘' : 'Ctrl'}K
					</kbd>
				{/if}
			</a>
		</nav>

		<!-- Organization + Projects -->
		<div class="mt-5 pt-4 border-t border-border">
			{#if !collapsed}
				<div class="flex items-center justify-between px-3 mb-2">
					<h3 class="text-[10px] font-bold uppercase tracking-widest text-text-dim font-mono truncate">
						{orgName}
					</h3>
				</div>
			{/if}

			<div class="space-y-3 {collapsed ? '' : 'mt-1'}">
				{#each projects as project (project.id)}
					{@const isActiveProject = $page.url.pathname.startsWith(`/projects/${project.id}`)}
					<div>
						<!-- Project header -->
						{#if !collapsed}
							<div class="flex items-center justify-between px-3 mb-0.5">
								<span
									class="text-[10px] font-mono font-bold uppercase tracking-wider truncate
										{isActiveProject ? 'text-text-primary' : 'text-text-dim'}"
								>
									{project.name}
								</span>
								<a
									href="/projects/{project.id}/settings"
									onclick={() => onNavigate?.()}
									class="text-text-dim hover:text-text-secondary transition-colors"
									title="Project settings"
								>
									<span class="material-symbols-outlined text-xs">settings</span>
								</a>
							</div>
						{/if}

						<!-- Module links -->
						<div class="space-y-0.5">
							{#each modules as mod (mod.id)}
								{@const href = mod.route(project.id)}
								<a
									{href}
									onclick={() => onNavigate?.()}
									class="w-full flex items-center gap-2.5 py-1.5 rounded-lg text-sm transition-colors
										{collapsed ? 'px-2 justify-center' : 'px-3'}
										{isModuleActive(href)
										? 'bg-phosphor-glow text-phosphor font-medium'
										: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary'}"
									title={collapsed ? `${project.name} - ${mod.label}` : ''}
								>
									<span class="material-symbols-outlined text-base">{mod.icon}</span>
									{#if !collapsed}
										<span class="truncate flex-1">{mod.label}</span>
										<span class="text-[10px] text-text-dim font-mono">
											{project.inbox_count}
										</span>
									{/if}
								</a>
							{/each}
						</div>
					</div>
				{/each}
				{#if projects.length === 0}
					{#if !collapsed}
						<p class="px-3 py-2 text-xs text-text-dim font-mono">No projects yet</p>
					{/if}
				{/if}
			</div>

			<!-- New project link -->
			{#if !collapsed}
				<a
					href="/projects"
					onclick={() => onNavigate?.()}
					class="flex items-center gap-2 px-3 py-2 mt-2 text-xs font-mono text-text-dim hover:text-phosphor transition-colors"
				>
					<span class="material-symbols-outlined text-sm">add</span>
					New Project
				</a>
			{/if}
		</div>
	</div>

	<!-- Footer: User pill -->
	<div class="p-4 pt-3 space-y-2 border-t border-border {collapsed ? 'px-2' : 'px-5'}">
		<!-- Trial status -->
		{#if isTrial && !collapsed}
			<div class="px-2 py-1.5 rounded-lg text-xs font-mono
				{trialActive ? 'text-amber' : 'text-error'}">
				{#if trialActive}
					Trial: {trialDaysLeft} day{trialDaysLeft !== 1 ? 's' : ''} left
				{:else}
					Trial expired
				{/if}
			</div>
		{/if}

		<!-- User row: name + settings + logout -->
		<div class="flex items-center gap-1.5 {collapsed ? 'flex-col' : ''}">
			{#if !collapsed}
				<span class="flex-1 text-sm font-mono text-text-primary truncate" title={userEmail}>
					{userName}
				</span>
			{/if}
			<a
				href="/settings"
				onclick={() => onNavigate?.()}
				class="size-7 flex items-center justify-center rounded-lg transition-colors
					{isSettingsActive
					? 'text-phosphor bg-phosphor-glow'
					: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary'}"
				title="Settings"
			>
				<span class="material-symbols-outlined text-lg">settings</span>
			</a>
			<button
				onclick={logout}
				class="size-7 flex items-center justify-center rounded-lg text-text-secondary hover:bg-surface-2 hover:text-error transition-colors"
				title="Logout"
			>
				<span class="material-symbols-outlined text-lg">logout</span>
			</button>
		</div>

		<!-- Connection status -->
		<div
			class="flex items-center gap-2 {collapsed ? 'justify-center' : 'px-1'}"
		>
			<div
				class="size-1.5 rounded-full shrink-0 {wsConnected
					? 'bg-phosphor'
					: 'bg-amber animate-pulse'}"
			></div>
			{#if !collapsed}
				<span class="text-[10px] font-mono text-text-secondary truncate">
					{wsConnected ? 'Connected' : 'Connecting...'}
				</span>
			{/if}
		</div>
	</div>
</aside>
