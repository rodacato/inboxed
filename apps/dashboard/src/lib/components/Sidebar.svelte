<script lang="ts">
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { getTheme } from '$lib/theme.svelte';
	import { clearStoredToken } from '$lib/api-client';
	import { fetchProjects } from '../../features/projects/projects.service';
	import type { Project } from '../../features/projects/projects.types';

	let { wsConnected = false }: { wsConnected?: boolean } = $props();
	const theme = getTheme();

	let projects = $state<Project[]>([]);

	onMount(async () => {
		try {
			const res = await fetchProjects();
			projects = res.projects;
		} catch {
			// ignore
		}
	});

	function logout() {
		clearStoredToken();
		window.location.href = '/login';
	}
</script>

<aside class="w-60 flex flex-col border-r border-border bg-surface shrink-0 h-full">
	<div class="p-5 flex-1 overflow-y-auto">
		<a href="/projects" class="flex items-center gap-3 mb-6">
			<div class="size-7 bg-phosphor rounded-lg flex items-center justify-center text-base">
				<span class="material-symbols-outlined text-lg">alternate_email</span>
			</div>
			<h1 class="font-display font-bold text-lg tracking-tight text-text-primary">Inboxed</h1>
		</a>

		<nav class="space-y-0.5">
			<a
				href="/search"
				class="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors
					{$page.url.pathname.startsWith('/search')
					? 'bg-phosphor-glow text-phosphor font-medium'
					: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary'}"
			>
				<span class="material-symbols-outlined text-lg">search</span>
				Search
			</a>
		</nav>

		<div class="mt-5 pt-4 border-t border-border">
			<div class="flex items-center justify-between px-3 mb-2">
				<h3 class="text-[10px] font-bold uppercase tracking-widest text-text-dim font-mono">
					Projects
				</h3>
				<a
					href="/projects"
					class="text-text-dim hover:text-text-secondary transition-colors"
					title="Manage projects"
				>
					<span class="material-symbols-outlined text-sm">settings</span>
				</a>
			</div>
			<div class="space-y-0.5">
				{#each projects as project (project.id)}
					<a
						href="/projects/{project.id}/emails"
						class="w-full flex items-center justify-between px-3 py-2 rounded-lg text-sm transition-colors
							{$page.url.pathname.startsWith(`/projects/${project.id}`)
							? 'bg-phosphor-glow text-phosphor font-medium'
							: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary'}"
					>
						<span class="truncate">{project.name}</span>
						<span class="text-[10px] text-text-dim font-mono">{project.inbox_count} inb</span>
					</a>
				{/each}
				{#if projects.length === 0}
					<p class="px-3 py-2 text-xs text-text-dim font-mono">No projects yet</p>
				{/if}
			</div>
		</div>
	</div>

	<div class="p-5 pt-3 space-y-3 border-t border-border">
		<div class="flex items-center gap-2">
			<button
				onclick={() => theme.toggle()}
				class="size-7 flex items-center justify-center rounded-lg text-text-secondary hover:bg-surface-2 hover:text-text-primary transition-colors"
				title={theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'}
			>
				<span class="material-symbols-outlined text-lg">
					{theme.isDark ? 'light_mode' : 'dark_mode'}
				</span>
			</button>
			<button
				onclick={logout}
				class="size-7 flex items-center justify-center rounded-lg text-text-secondary hover:bg-surface-2 hover:text-error transition-colors"
				title="Logout"
			>
				<span class="material-symbols-outlined text-lg">logout</span>
			</button>
		</div>
		<div class="flex items-center gap-2 px-3 py-2 rounded-lg bg-surface-2 border border-border">
			<div
				class="size-1.5 rounded-full {wsConnected ? 'bg-phosphor' : 'bg-amber animate-pulse'}"
			></div>
			<span class="text-[10px] font-mono text-text-secondary truncate">
				{wsConnected ? 'Connected' : 'Connecting...'}
			</span>
		</div>
	</div>
</aside>
