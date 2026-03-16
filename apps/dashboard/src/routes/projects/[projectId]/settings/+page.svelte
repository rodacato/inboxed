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
	} from '../../../../features/projects/projects.service';
	import { fetchInboxes } from '../../../../features/inboxes/inboxes.service';
	import { fetchEndpoints } from '../../../../features/hooks/hooks.service';
	import { getRealtimeStore } from '../../../../features/realtime/realtime.store.svelte';
	import { projectsStore } from '$lib/stores/projects.store.svelte';
	import { authStore } from '$lib/stores/auth.store.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import CreateEndpointDialog from '../../../../features/hooks/components/CreateEndpointDialog.svelte';
	import EditEndpointDialog from '../../../../features/hooks/components/EditEndpointDialog.svelte';
	import TryEndpointDialog from '../../../../features/hooks/components/TryEndpointDialog.svelte';
	import type { Project, ApiKey } from '../../../../features/projects/projects.types';
	import type { Inbox } from '../../../../features/inboxes/inboxes.types';
	import type { HttpEndpoint } from '../../../../features/hooks/hooks.types';

	const projectId = $derived($page.params.projectId ?? '');
	const realtime = getRealtimeStore();

	let project = $state<Project | null>(null);
	let apiKeys = $state<ApiKey[]>([]);
	let inboxes = $state<Inbox[]>([]);
	let endpoints = $state<HttpEndpoint[]>([]);
	let loading = $state(true);
	let newKeyLabel = $state('');
	let creatingKey = $state(false);
	let newToken = $state<string | null>(null);
	let copied = $state(false);
	let copiedSnippet = $state<string | null>(null);
	let showCreateEndpoint = $state(false);
	let editingEndpoint = $state<HttpEndpoint | null>(null);
	let tryingEndpoint = $state<HttpEndpoint | null>(null);
	let unsubscribe: (() => void) | undefined;

	const smtp = $derived(authStore.smtp);
	const smtpHost = $derived(smtp?.host ?? 'localhost');
	const smtpPort = $derived(smtp?.port ?? 2525);
	const apiKeyHint = $derived(
		apiKeys.length > 0 ? `${apiKeys[0].token_prefix}...` : '<your-api-key>'
	);

	type QuickStartTab = 'smtp' | 'curl';
	let activeTab = $state<QuickStartTab>('smtp');

	const quickStartTabs: { id: QuickStartTab; label: string; icon: string; iconColor: string }[] = [
		{ id: 'smtp', label: 'SMTP', icon: 'mail', iconColor: 'text-phosphor' },
		{ id: 'curl', label: 'Test Email', icon: 'terminal', iconColor: 'text-cyan' }
	];

	const snippets = $derived(project ? {
		smtp: {
			code: `SMTP_HOST=${smtpHost}\nSMTP_PORT=${smtpPort}\nSMTP_USERNAME=${project.slug}\nSMTP_PASSWORD=${apiKeyHint}`,
			description: 'Point your app\'s SMTP config here.',
			hint: apiKeys.length === 0 ? 'Create an API key below to use as SMTP_PASSWORD.' : null
		},
		curl: {
			code: `curl --url "smtp://${smtpHost}:${smtpPort}" \\\n  --user "${project.slug}:${apiKeyHint}" \\\n  --mail-from "test@example.com" \\\n  --mail-rcpt "hello@${project.slug}.test" \\\n  --upload-file - <<EOF\nFrom: test@example.com\nTo: hello@${project.slug}.test\nSubject: Hello from Inboxed\n\nYour first test email!\nEOF`,
			description: 'Send your first email via curl.',
			hint: apiKeys.length === 0 ? 'You\'ll need an API key first — create one below.' : null
		}
	} : null);

	const activeSnippet = $derived(snippets ? snippets[activeTab] : null);

	const endpointTypeIcons: Record<string, string> = {
		webhook: 'webhook',
		form: 'description',
		heartbeat: 'favorite'
	};


	async function copySnippet(text: string, key: string) {
		await navigator.clipboard.writeText(text);
		copiedSnippet = key;
		setTimeout(() => { copiedSnippet = null; }, 2000);
	}

	onMount(async () => {
		const [projRes, keysRes, inboxRes, endpointsRes] = await Promise.all([
			fetchProject(projectId),
			fetchApiKeys(projectId),
			fetchInboxes(projectId),
			fetchEndpoints(projectId)
		]);
		project = projRes.project;
		apiKeys = keysRes.api_keys;
		inboxes = inboxRes.inboxes;
		endpoints = endpointsRes.endpoints;
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
		projectsStore.remove(projectId);
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
		<!-- Project Info -->
		<div class="flex items-start justify-between mb-8">
			<div>
				<h2 class="text-2xl font-display font-bold text-text-primary">{project.name}</h2>
				<p class="text-sm font-mono text-text-dim mt-1">{project.slug}</p>
			</div>
			<button
				onclick={handleDeleteProject}
				class="px-3 py-1.5 text-xs font-mono text-error border border-error/30 rounded hover:bg-error/10 transition-colors"
			>
				Delete Project
			</button>
		</div>

		<div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
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

		<!-- Quick Start -->
		{#if snippets && activeSnippet}
			<section class="mb-8">
				<h3 class="text-lg font-display font-bold text-text-primary mb-4">Quick Start</h3>
				<div class="rounded-lg border border-border bg-surface overflow-hidden">
					<!-- Tabs -->
					<div class="flex border-b border-border bg-surface-2">
						{#each quickStartTabs as tab (tab.id)}
							<button
								onclick={() => { activeTab = tab.id; }}
								class="flex items-center gap-1.5 px-4 py-2.5 text-xs font-mono whitespace-nowrap transition-colors border-b-2 -mb-px
									{activeTab === tab.id
										? 'border-phosphor text-phosphor bg-surface'
										: 'border-transparent text-text-secondary hover:text-text-primary hover:bg-surface/50'}"
							>
								<span class="material-symbols-outlined text-sm {activeTab === tab.id ? tab.iconColor : ''}">{tab.icon}</span>
								{tab.label}
							</button>
						{/each}
					</div>

					<!-- Content -->
					<div class="p-4">
						<p class="text-xs text-text-secondary font-mono mb-3">{activeSnippet.description}</p>
						<div class="relative">
							<pre class="bg-surface-2 border border-border rounded px-3 py-2 text-xs font-mono text-text-primary overflow-x-auto">{activeSnippet.code}</pre>
							<button
								onclick={() => copySnippet(activeSnippet!.code, activeTab)}
								class="absolute top-2 right-2 px-2 py-0.5 bg-surface border border-border rounded text-[10px] font-mono text-text-dim hover:text-text-primary hover:border-phosphor transition-colors"
							>
								{copiedSnippet === activeTab ? 'Copied!' : 'Copy'}
							</button>
						</div>
						{#if activeSnippet.hint}
							<p class="text-[10px] font-mono mt-2 text-amber">
								{activeSnippet.hint}
							</p>
						{/if}
					</div>
				</div>
			</section>
		{/if}

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
						<code
							class="flex-1 text-sm font-mono text-text-primary bg-surface p-2 rounded border border-border break-all"
						>
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
				<EmptyState
					icon="key"
					title="No API keys yet"
					description="Generate an API key to authenticate SMTP connections and API requests."
				/>
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

		<!-- Endpoints -->
		<section class="mb-8">
			<div class="flex items-center justify-between mb-4">
				<h3 class="text-lg font-display font-bold text-text-primary">Endpoints</h3>
				<button
					onclick={() => (showCreateEndpoint = true)}
					class="px-3 py-1.5 bg-phosphor text-base rounded text-xs font-mono font-medium hover:brightness-110"
				>
					+ Create
				</button>
			</div>

			{#if endpoints.length === 0}
				<EmptyState
					icon="webhook"
					title="No endpoints yet"
					description="Create an endpoint to start catching webhooks, form submissions, or heartbeats."
				/>
			{:else}
				<div class="rounded-lg border border-border overflow-hidden">
					<table class="w-full text-sm">
						<thead class="bg-surface-2">
							<tr class="text-left text-xs font-mono text-text-dim uppercase">
								<th class="px-4 py-3">Label</th>
								<th class="px-4 py-3">Type</th>
								<th class="px-4 py-3">Token</th>
								<th class="px-4 py-3">Requests</th>
								<th class="px-4 py-3 w-12"></th>
							</tr>
						</thead>
						<tbody>
							{#each endpoints as ep (ep.id)}
								<tr class="border-t border-border hover:bg-surface-2/50">
									<td class="px-4 py-3 font-mono text-text-primary">{ep.label || '—'}</td>
									<td class="px-4 py-3">
										<span class="inline-flex items-center gap-1.5 text-text-secondary">
											<span class="material-symbols-outlined text-sm">{endpointTypeIcons[ep.endpoint_type] ?? 'link'}</span>
											<span class="text-xs font-mono">{ep.endpoint_type}</span>
										</span>
									</td>
									<td class="px-4 py-3 font-mono text-text-secondary text-xs">{ep.token}</td>
									<td class="px-4 py-3 font-mono text-text-secondary">{ep.request_count}</td>
									<td class="px-4 py-3">
										<div class="flex items-center gap-1">
											<button
												onclick={() => (tryingEndpoint = ep)}
												class="text-text-dim hover:text-phosphor transition-colors"
												title="Try it"
											>
												<span class="material-symbols-outlined text-lg">terminal</span>
											</button>
											<button
												onclick={() => (editingEndpoint = ep)}
												class="text-text-dim hover:text-text-primary transition-colors"
												title="Edit endpoint"
											>
												<span class="material-symbols-outlined text-lg">settings</span>
											</button>
										</div>
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
				<EmptyState
					icon="inbox"
					title="No inboxes yet"
					description="Send an email to create one automatically."
				/>
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
											href="/projects/{projectId}/mail/inbox/{inbox.id}"
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

	<CreateEndpointDialog
		{projectId}
		bind:open={showCreateEndpoint}
		onCreate={(ep) => { endpoints = [ep, ...endpoints]; }}
	/>
	<EditEndpointDialog
		{projectId}
		bind:endpoint={editingEndpoint}
		onUpdate={(ep) => { endpoints = endpoints.map((e) => e.id === ep.id ? ep : e); }}
		onDelete={(ep) => { endpoints = endpoints.filter((e) => e.id !== ep.id); }}
	/>
	<TryEndpointDialog bind:endpoint={tryingEndpoint} />
{/if}
