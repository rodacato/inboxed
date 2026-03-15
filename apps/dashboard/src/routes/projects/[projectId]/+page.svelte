<script lang="ts">
	import { page } from '$app/stores';
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import {
		fetchProject,
		deleteProject,
		fetchApiKeys,
		createApiKey,
		deleteApiKey
	} from '../../../features/projects/projects.service';
	import { fetchInboxes } from '../../../features/inboxes/inboxes.service';
	import { getRealtimeStore } from '../../../features/realtime/realtime.store.svelte';
	import type { Project, ApiKey } from '../../../features/projects/projects.types';
	import type { Inbox } from '../../../features/inboxes/inboxes.types';

	const projectId = $derived($page.params.projectId);
	const realtime = getRealtimeStore();

	let project = $state<Project | null>(null);
	let apiKeys = $state<ApiKey[]>([]);
	let inboxes = $state<Inbox[]>([]);
	let loading = $state(true);
	let newKeyLabel = $state('');
	let creatingKey = $state(false);
	let newToken = $state<string | null>(null);
	let copied = $state(false);
	let unsubscribe: (() => void) | undefined;

	onMount(async () => {
		const [projRes, keysRes, inboxRes] = await Promise.all([
			fetchProject(projectId),
			fetchApiKeys(projectId),
			fetchInboxes(projectId)
		]);
		project = projRes.project;
		apiKeys = keysRes.api_keys;
		inboxes = inboxRes.inboxes;
		loading = false;

		unsubscribe = realtime.subscribeToProject(projectId, (msg) => {
			if (msg.type === 'inbox_created') {
				const inbox = msg.inbox as Inbox;
				inboxes = [inbox, ...inboxes];
			} else if (msg.type === 'inbox_updated') {
				const inboxId = msg.inbox_id as string;
				const delta = msg.email_count_delta as number;
				inboxes = inboxes.map((i) =>
					i.id === inboxId ? { ...i, email_count: i.email_count + delta } : i
				);
			}
		});
	});

	onDestroy(() => unsubscribe?.());

	async function handleCreateKey() {
		if (!newKeyLabel.trim()) return;
		creatingKey = true;
		try {
			const res = await createApiKey(projectId, newKeyLabel);
			newToken = res.api_key.token;
			apiKeys = [res.api_key, ...apiKeys];
			newKeyLabel = '';
		} finally {
			creatingKey = false;
		}
	}

	async function handleDeleteKey(id: string) {
		if (!confirm('Revoke this API key? This cannot be undone.')) return;
		await deleteApiKey(id);
		apiKeys = apiKeys.filter((k) => k.id !== id);
	}

	async function handleDeleteProject() {
		if (!confirm(`Delete project "${project?.name}" and ALL its data? This cannot be undone.`))
			return;
		await deleteProject(projectId);
		goto('/projects');
	}

	function copyToken() {
		if (newToken) {
			navigator.clipboard.writeText(newToken);
			copied = true;
			setTimeout(() => (copied = false), 2000);
		}
	}

	function timeAgo(iso: string | null): string {
		if (!iso) return 'never';
		const diff = Date.now() - new Date(iso).getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 60) return `${mins}m ago`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h ago`;
		return `${Math.floor(hours / 24)}d ago`;
	}
</script>

{#if loading}
	<div class="p-8">
		<p class="text-text-dim font-mono text-sm">Loading...</p>
	</div>
{:else if project}
	<div class="p-8 overflow-auto h-full">
		<!-- Breadcrumb -->
		<div class="flex items-center gap-2 text-sm font-mono text-text-secondary mb-6">
			<a href="/projects" class="hover:text-phosphor">Projects</a>
			<span class="text-text-dim">/</span>
			<span class="text-text-primary">{project.name}</span>
		</div>

		<!-- Project Info -->
		<div class="flex items-start justify-between mb-8">
			<div>
				<h2 class="text-2xl font-display font-bold text-text-primary">{project.name}</h2>
				<p class="text-sm font-mono text-text-dim mt-1">{project.slug}</p>
			</div>
			<div class="flex gap-2">
				<a
					href="/projects/{projectId}/emails"
					class="flex items-center gap-2 px-4 py-2 bg-phosphor text-base rounded-lg text-sm font-mono font-medium hover:brightness-110 transition-all"
				>
					<span class="material-symbols-outlined text-lg">mail</span>
					View Emails
				</a>
				<button
					onclick={handleDeleteProject}
					class="px-3 py-1.5 text-xs font-mono text-error border border-error/30 rounded hover:bg-error/10 transition-colors"
				>
					Delete
				</button>
			</div>
		</div>

		<div class="grid grid-cols-3 gap-4 mb-8">
			<div class="p-4 rounded-lg bg-surface border border-border">
				<p class="text-xs font-mono text-text-dim uppercase">TTL</p>
				<p class="text-lg font-display font-bold text-text-primary mt-1">
					{project.default_ttl_hours ?? 168}h
				</p>
			</div>
			<div class="p-4 rounded-lg bg-surface border border-border">
				<p class="text-xs font-mono text-text-dim uppercase">Max Inboxes</p>
				<p class="text-lg font-display font-bold text-text-primary mt-1">
					{project.max_inbox_count}
				</p>
			</div>
			<div class="p-4 rounded-lg bg-surface border border-border">
				<p class="text-xs font-mono text-text-dim uppercase">Inboxes</p>
				<p class="text-lg font-display font-bold text-text-primary mt-1">
					{inboxes.length}
				</p>
			</div>
		</div>

		<!-- API Keys -->
		<section class="mb-8">
			<div class="flex items-center justify-between mb-4">
				<h3 class="text-lg font-display font-bold text-text-primary">API Keys</h3>
			</div>

			{#if newToken}
				<div class="mb-4 p-4 rounded-lg border border-phosphor/30 bg-phosphor-glow">
					<p class="text-xs font-mono text-phosphor font-bold mb-2">
						New API key created — copy it now, it won't be shown again:
					</p>
					<div class="flex items-center gap-2">
						<code class="flex-1 text-sm font-mono text-text-primary bg-surface p-2 rounded border border-border break-all">
							{newToken}
						</code>
						<button
							onclick={copyToken}
							class="px-3 py-2 bg-phosphor text-base rounded text-xs font-mono font-medium hover:brightness-110"
						>
							{copied ? 'Copied!' : 'Copy'}
						</button>
					</div>
					<button
						onclick={() => (newToken = null)}
						class="mt-2 text-xs font-mono text-text-secondary hover:text-text-primary"
					>
						Dismiss
					</button>
				</div>
			{/if}

			<form
				onsubmit={(e) => {
					e.preventDefault();
					handleCreateKey();
				}}
				class="flex gap-3 mb-4"
			>
				<input
					type="text"
					bind:value={newKeyLabel}
					placeholder="Key label (e.g. CI Pipeline)"
					class="flex-1 bg-surface-2 border border-border rounded px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor"
				/>
				<button
					type="submit"
					disabled={creatingKey || !newKeyLabel.trim()}
					class="px-4 py-2 bg-phosphor text-base rounded text-sm font-mono font-medium hover:brightness-110 disabled:opacity-50"
				>
					Generate
				</button>
			</form>

			{#if apiKeys.length === 0}
				<p class="text-sm font-mono text-text-dim">No API keys yet.</p>
			{:else}
				<div class="rounded-lg border border-border overflow-hidden">
					<table class="w-full text-sm">
						<thead class="bg-surface-2">
							<tr class="text-left text-xs font-mono text-text-dim uppercase">
								<th class="px-4 py-3">Label</th>
								<th class="px-4 py-3">Prefix</th>
								<th class="px-4 py-3">Last Used</th>
								<th class="px-4 py-3 w-12"></th>
							</tr>
						</thead>
						<tbody>
							{#each apiKeys as key (key.id)}
								<tr class="border-t border-border hover:bg-surface-2/50">
									<td class="px-4 py-3 font-mono text-text-primary">{key.label}</td>
									<td class="px-4 py-3 font-mono text-text-secondary">{key.token_prefix}***</td>
									<td class="px-4 py-3 font-mono text-text-secondary"
										>{timeAgo(key.last_used_at)}</td
									>
									<td class="px-4 py-3">
										<button
											onclick={() => handleDeleteKey(key.id)}
											class="text-text-dim hover:text-error transition-colors"
											title="Revoke key"
										>
											<span class="material-symbols-outlined text-lg">delete</span>
										</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</section>

		<!-- Inboxes -->
		<section>
			<h3 class="text-lg font-display font-bold text-text-primary mb-4">Inboxes</h3>
			{#if inboxes.length === 0}
				<p class="text-sm font-mono text-text-dim">
					No inboxes yet. Send an email to create one automatically.
				</p>
			{:else}
				<div class="rounded-lg border border-border overflow-hidden">
					<table class="w-full text-sm">
						<thead class="bg-surface-2">
							<tr class="text-left text-xs font-mono text-text-dim uppercase">
								<th class="px-4 py-3">Address</th>
								<th class="px-4 py-3">Emails</th>
								<th class="px-4 py-3">Created</th>
							</tr>
						</thead>
						<tbody>
							{#each inboxes as inbox (inbox.id)}
								<tr class="border-t border-border hover:bg-surface-2/50 cursor-pointer">
									<td class="px-4 py-3">
										<a
											href="/projects/{projectId}/inboxes/{inbox.id}"
											class="font-mono text-phosphor hover:underline"
										>
											{inbox.address}
										</a>
									</td>
									<td class="px-4 py-3 font-mono text-text-secondary">{inbox.email_count}</td>
									<td class="px-4 py-3 font-mono text-text-secondary"
										>{timeAgo(inbox.created_at)}</td
									>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</section>
	</div>
{/if}
