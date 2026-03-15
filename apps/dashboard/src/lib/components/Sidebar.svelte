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

<aside class="w-64 flex flex-col border-r border-border bg-surface shrink-0">
	<div class="p-6">
		<a href="/projects" class="flex items-center gap-3 mb-8">
			<div class="size-8 bg-phosphor rounded-lg flex items-center justify-center text-base">
				<span class="material-symbols-outlined">alternate_email</span>
			</div>
			<h1 class="font-display font-bold text-xl tracking-tight text-text-primary">Inboxed</h1>
		</a>

		<nav class="space-y-1">
			<a
				href="/search"
				class="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition-colors
					{$page.url.pathname.startsWith('/search')
					? 'bg-phosphor-glow text-phosphor font-medium'
					: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary'}"
			>
				<span class="material-symbols-outlined text-xl">search</span>
				Search
			</a>
		</nav>

		<div class="mt-6 pt-4 border-t border-border">
			<h3
				class="px-4 text-[10px] font-bold uppercase tracking-widest text-text-dim mb-3 font-mono"
			>
				Projects
			</h3>
			<div class="space-y-0.5">
				{#each projects as project (project.id)}
					<a
						href="/projects/{project.id}"
						class="w-full flex items-center justify-between px-4 py-2 rounded-lg text-sm transition-colors
							{$page.url.pathname.startsWith(`/projects/${project.id}`)
							? 'bg-phosphor-glow text-phosphor font-medium'
							: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary'}"
					>
						<span class="truncate">{project.name}</span>
						<span class="text-xs text-text-dim font-mono">{project.inbox_count}</span>
					</a>
				{/each}
				{#if projects.length === 0}
					<p class="px-4 py-2 text-xs text-text-dim font-mono">No projects yet</p>
				{/if}
			</div>
		</div>
	</div>

	<div class="mt-auto p-6 space-y-3">
		<div class="flex items-center gap-2">
			<button
				onclick={() => theme.toggle()}
				class="size-8 flex items-center justify-center rounded-lg text-text-secondary hover:bg-surface-2 hover:text-text-primary transition-colors"
				title={theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'}
			>
				<span class="material-symbols-outlined text-lg">
					{theme.isDark ? 'light_mode' : 'dark_mode'}
				</span>
			</button>
			<button
				onclick={logout}
				class="size-8 flex items-center justify-center rounded-lg text-text-secondary hover:bg-surface-2 hover:text-error transition-colors"
				title="Logout"
			>
				<span class="material-symbols-outlined text-lg">logout</span>
			</button>
		</div>
		<div class="flex items-center gap-3 p-3 rounded-lg bg-surface-2 border border-border">
			<div
				class="size-2 rounded-full {wsConnected ? 'bg-phosphor' : 'bg-amber animate-pulse'}"
			></div>
			<span class="text-xs font-mono text-text-secondary truncate">
				{wsConnected ? 'Connected' : 'Connecting...'}
			</span>
		</div>
	</div>
</aside>
