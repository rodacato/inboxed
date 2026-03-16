<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { createProject, updateProject, deleteProject } from '../../../features/projects/projects.service';
	import { projectsStore } from '$lib/stores/projects.store.svelte';
	import { authStore } from '$lib/stores/auth.store.svelte';
	import type { Project } from '../../../features/projects/projects.types';

	const projects = $derived(projectsStore.projects);
	const isAdmin = $derived(authStore.isOrgAdmin);
	let loading = $state(true);

	// Create form
	let showCreate = $state(false);
	let newName = $state('');
	let newSlug = $state('');
	let creating = $state(false);

	// Inline edit
	let editingId = $state<string | null>(null);
	let editName = $state('');
	let savingEdit = $state(false);

	onMount(async () => {
		if (!projectsStore.loaded) {
			await projectsStore.load();
		}
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
			projectsStore.add(res.project);
			showCreate = false;
			newName = '';
			newSlug = '';
		} finally {
			creating = false;
		}
	}

	function startEdit(project: Project) {
		editingId = project.id;
		editName = project.name;
	}

	function cancelEdit() {
		editingId = null;
		editName = '';
	}

	async function saveEdit(id: string) {
		if (!editName.trim()) return;
		savingEdit = true;
		try {
			await updateProject(id, { name: editName });
			await projectsStore.load();
			editingId = null;
			editName = '';
		} finally {
			savingEdit = false;
		}
	}

	async function handleDelete(project: Project) {
		if (!confirm(`Delete project "${project.name}" and ALL its data? This cannot be undone.`)) return;
		await deleteProject(project.id);
		projectsStore.remove(project.id);
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

<div class="max-w-3xl mx-auto p-6">
	<div class="flex items-center justify-between mb-6">
		<h1 class="text-xl font-display font-bold text-text-primary">Projects</h1>
		{#if isAdmin}
			<button
				onclick={() => (showCreate = true)}
				class="flex items-center gap-2 px-4 py-2 bg-phosphor text-base rounded-lg text-sm font-mono font-medium hover:brightness-110 transition-all"
			>
				<span class="material-symbols-outlined text-lg">add</span>
				New Project
			</button>
		{/if}
	</div>

	<!-- Create form -->
	{#if showCreate}
		<div class="mb-6 p-4 rounded-lg border border-border bg-surface">
			<form
				onsubmit={(e) => { e.preventDefault(); handleCreate(); }}
				class="flex gap-3 items-end"
			>
				<div class="flex-1">
					<label class="block text-xs font-mono text-text-dim uppercase mb-1" for="new-proj-name">Name</label>
					<input
						id="new-proj-name"
						type="text"
						bind:value={newName}
						oninput={autoSlug}
						placeholder="My SaaS App"
						class="w-full bg-base border border-border rounded px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
					/>
				</div>
				<div class="flex-1">
					<label class="block text-xs font-mono text-text-dim uppercase mb-1" for="new-proj-slug">Slug</label>
					<input
						id="new-proj-slug"
						type="text"
						bind:value={newSlug}
						placeholder="my-saas-app"
						class="w-full bg-base border border-border rounded px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
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

	<!-- Projects list -->
	{#if loading}
		<p class="text-text-dim font-mono text-sm">Loading...</p>
	{:else if projects.length === 0}
		<div class="py-12 text-center">
			<span class="material-symbols-outlined text-4xl text-text-dim mb-3">folder_open</span>
			<p class="text-sm font-mono text-text-dim">No projects yet</p>
		</div>
	{:else}
		<div class="bg-surface border border-border rounded-lg divide-y divide-border">
			{#each projects as project (project.id)}
				<div class="flex items-center justify-between px-4 py-3">
					<div class="flex items-center gap-3 min-w-0 flex-1">
						{#if editingId === project.id}
							<form
								onsubmit={(e) => { e.preventDefault(); saveEdit(project.id); }}
								class="flex items-center gap-2 flex-1"
							>
								<input
									type="text"
									bind:value={editName}
									class="flex-1 bg-base border border-border rounded px-2 py-1 text-sm font-mono text-text-primary focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
								/>
								<button
									type="submit"
									disabled={savingEdit || !editName.trim()}
									class="text-xs font-mono text-phosphor hover:underline disabled:opacity-50"
								>
									{savingEdit ? 'Saving...' : 'Save'}
								</button>
								<button
									type="button"
									onclick={cancelEdit}
									class="text-xs font-mono text-text-secondary hover:text-text-primary"
								>
									Cancel
								</button>
							</form>
						{:else}
							<div class="min-w-0">
								<a
									href="/projects/{project.id}/settings"
									class="font-mono text-sm text-text-primary hover:text-phosphor transition-colors"
								>
									{project.name}
								</a>
								<p class="text-[10px] font-mono text-text-dim">{project.slug}</p>
							</div>
						{/if}
					</div>
					<div class="flex items-center gap-3 shrink-0 ml-4">
						<span class="text-xs font-mono text-text-dim">{project.inbox_count} inboxes</span>
						<span class="text-xs font-mono text-text-dim">Created {timeAgo(project.created_at)}</span>
						{#if isAdmin && editingId !== project.id}
							<button
								onclick={() => startEdit(project)}
								class="text-text-dim hover:text-text-secondary transition-colors"
								title="Rename"
							>
								<span class="material-symbols-outlined text-sm">edit</span>
							</button>
							<button
								onclick={() => handleDelete(project)}
								class="text-text-dim hover:text-error transition-colors"
								title="Delete project"
							>
								<span class="material-symbols-outlined text-sm">delete</span>
							</button>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>
