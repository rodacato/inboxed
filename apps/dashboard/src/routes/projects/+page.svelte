<script lang="ts">
	import { onMount } from 'svelte';
	import { fetchProjects, createProject } from '../../features/projects/projects.service';
	import type { Project } from '../../features/projects/projects.types';

	let projects = $state<Project[]>([]);
	let loading = $state(true);
	let showCreate = $state(false);
	let newName = $state('');
	let newSlug = $state('');
	let creating = $state(false);

	onMount(async () => {
		const res = await fetchProjects();
		projects = res.projects;
		loading = false;
	});

	function autoSlug() {
		newSlug = newName
			.toLowerCase()
			.replace(/[^a-z0-9]+/g, '-')
			.replace(/^-|-$/g, '');
	}

	async function handleCreate() {
		if (!newName.trim() || !newSlug.trim()) return;
		creating = true;
		try {
			const res = await createProject({ name: newName, slug: newSlug });
			projects = [res.project, ...projects];
			showCreate = false;
			newName = '';
			newSlug = '';
		} finally {
			creating = false;
		}
	}

	function timeAgo(iso: string): string {
		const diff = Date.now() - new Date(iso).getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 60) return `${mins}m ago`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h ago`;
		return `${Math.floor(hours / 24)}d ago`;
	}
</script>

<div class="p-8 overflow-auto h-full">
	<div class="flex items-center justify-between mb-8">
		<h2 class="text-2xl font-display font-bold text-text-primary">Projects</h2>
		<button
			onclick={() => (showCreate = true)}
			class="flex items-center gap-2 px-4 py-2 bg-phosphor text-base rounded-lg text-sm font-mono font-medium hover:brightness-110 transition-all"
		>
			<span class="material-symbols-outlined text-lg">add</span>
			New Project
		</button>
	</div>

	{#if showCreate}
		<div class="mb-8 p-6 rounded-lg border border-border bg-surface">
			<h3 class="text-sm font-mono font-bold text-text-primary mb-4">Create Project</h3>
			<form
				onsubmit={(e) => {
					e.preventDefault();
					handleCreate();
				}}
				class="flex gap-4 items-end"
			>
				<div class="flex-1">
					<label class="block text-xs font-mono text-text-dim uppercase mb-1" for="proj-name"
						>Name</label
					>
					<input
						id="proj-name"
						type="text"
						bind:value={newName}
						oninput={autoSlug}
						placeholder="My SaaS App"
						class="w-full bg-surface-2 border border-border rounded px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor"
					/>
				</div>
				<div class="flex-1">
					<label class="block text-xs font-mono text-text-dim uppercase mb-1" for="proj-slug"
						>Slug</label
					>
					<input
						id="proj-slug"
						type="text"
						bind:value={newSlug}
						placeholder="my-saas-app"
						class="w-full bg-surface-2 border border-border rounded px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor"
					/>
				</div>
				<button
					type="submit"
					disabled={creating || !newName.trim()}
					class="px-4 py-2 bg-phosphor text-base rounded text-sm font-mono font-medium hover:brightness-110 disabled:opacity-50"
				>
					{creating ? 'Creating...' : 'Create'}
				</button>
				<button
					type="button"
					onclick={() => (showCreate = false)}
					class="px-4 py-2 text-text-secondary hover:text-text-primary text-sm font-mono"
				>
					Cancel
				</button>
			</form>
		</div>
	{/if}

	{#if loading}
		<p class="text-text-dim font-mono text-sm">Loading projects...</p>
	{:else if projects.length === 0}
		<div class="text-center py-20">
			<span class="material-symbols-outlined text-5xl text-text-dim mb-4">folder_open</span>
			<p class="text-text-secondary font-mono">No projects yet. Create one to get started.</p>
		</div>
	{:else}
		<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
			{#each projects as project (project.id)}
				<a
					href="/projects/{project.id}"
					class="block p-6 rounded-lg border border-border bg-surface hover:border-phosphor/30 hover:bg-surface-2 transition-all group"
				>
					<h3
						class="font-display font-bold text-text-primary group-hover:text-phosphor transition-colors"
					>
						{project.name}
					</h3>
					<p class="text-xs font-mono text-text-dim mt-1">{project.slug}</p>
					<div class="mt-4 flex items-center gap-4 text-xs font-mono text-text-secondary">
						<span>{project.inbox_count} inboxes</span>
						<span>TTL: {project.default_ttl_hours ?? 168}h</span>
					</div>
					<p class="text-xs font-mono text-text-dim mt-2">Created {timeAgo(project.created_at)}</p>
				</a>
			{/each}
		</div>
	{/if}
</div>
