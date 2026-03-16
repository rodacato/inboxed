<script lang="ts">
	import { page } from '$app/stores';
	import { fetchEndpoints, deleteEndpoint } from '../../../../features/hooks/hooks.service';
	import { getRealtimeStore } from '../../../../features/realtime/realtime.store.svelte';
	import { toastStore } from '$lib/stores/toast.store.svelte';
	import type { HttpEndpoint } from '../../../../features/hooks/hooks.types';
	import type { Pagination } from '../../../../features/projects/projects.types';
	import SplitPane from '$lib/components/SplitPane.svelte';
	import FilterableList from '$lib/components/FilterableList.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import CreateEndpointDialog from '../../../../features/hooks/components/CreateEndpointDialog.svelte';

	const projectId = $derived($page.params.projectId ?? '');
	const realtime = getRealtimeStore();

	let endpoints = $state<HttpEndpoint[]>([]);
	let pagination = $state<Pagination | null>(null);
	let loading = $state(true);
	let selectedEndpoint = $state<HttpEndpoint | null>(null);
	let showCreate = $state(false);
	let unsubscribe: (() => void) | undefined;

	$effect(() => {
		const pid = projectId;
		if (!pid) return;
		endpoints = [];
		loading = true;
		selectedEndpoint = null;
		unsubscribe?.();

		loadEndpoints(pid);
	});

	async function loadEndpoints(pid: string) {
		const res = await fetchEndpoints(pid, { type: 'webhook' });
		if (pid !== projectId) return;
		endpoints = res.endpoints;
		pagination = res.pagination;
		loading = false;

		unsubscribe = realtime.subscribeToProject(pid, (msg) => {
			if (msg.type === 'request_captured' && msg.endpoint_type === 'webhook') {
				const ep = endpoints.find((e) => e.id === msg.endpoint_id);
				if (ep) {
					endpoints = endpoints.map((e) =>
						e.id === msg.endpoint_id ? { ...e, request_count: e.request_count + 1 } : e
					);
					toastStore.add({
						type: 'success',
						title: `${(msg.request as { method: string })?.method ?? 'POST'} request captured`,
						description: ep.label ?? ep.token.slice(0, 8)
					});
				}
			} else if (msg.type === 'endpoint_created' && (msg.endpoint as { endpoint_type: string })?.endpoint_type === 'webhook') {
				const ep = msg.endpoint as HttpEndpoint;
				endpoints = [{ ...ep, request_count: 0, url: '', allowed_methods: ['POST'], allowed_ips: [], max_body_bytes: 262144, response_mode: null, response_redirect_url: null, expected_interval_seconds: null, heartbeat_status: null, last_ping_at: null, status_changed_at: null, description: null, created_at: new Date().toISOString(), updated_at: new Date().toISOString() }, ...endpoints];
			} else if (msg.type === 'endpoint_deleted') {
				endpoints = endpoints.filter((e) => e.id !== msg.endpoint_id);
			}
		});
	}

	async function handleSelectEndpoint(ep: HttpEndpoint) {
		selectedEndpoint = ep;
	}

	async function handleDeleteEndpoint(ep: HttpEndpoint) {
		if (!confirm(`Delete endpoint "${ep.label || ep.token.slice(0, 8)}" and ALL its data?`)) return;
		await deleteEndpoint(projectId, ep.token);
		endpoints = endpoints.filter((e) => e.id !== ep.id);
		if (selectedEndpoint?.id === ep.id) {
			selectedEndpoint = null;
		}
	}

	function handleEndpointCreated(ep: HttpEndpoint) {
		endpoints = [ep, ...endpoints];
		selectedEndpoint = ep;
		toastStore.add({ type: 'success', title: 'Endpoint created', description: ep.label ?? ep.token.slice(0, 8) });
	}

	function timeAgo(iso: string): string {
		const diff = Date.now() - new Date(iso).getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 1) return 'now';
		if (mins < 60) return `${mins}m`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h`;
		return `${Math.floor(hours / 24)}d`;
	}
</script>

<SplitPane showDetail={!!selectedEndpoint}>
	{#snippet list()}
		<FilterableList title="Hooks In" totalCount={pagination?.total_count} {loading}>
			{#snippet headerActions()}
				<button
					onclick={() => (showCreate = true)}
					class="px-3 py-1.5 bg-phosphor text-base rounded text-xs font-mono font-medium hover:brightness-110"
				>
					+ Create
				</button>
			{/snippet}
			{#snippet items()}
				{#if endpoints.length === 0}
					<EmptyState
						icon="webhook"
						title="No webhook endpoints yet"
						description="Create an endpoint to start catching HTTP requests."
					>
						{#snippet content()}
							<pre class="text-xs font-mono text-text-secondary bg-surface-2 p-3 rounded mt-2 text-left">curl -X POST https://your-domain/hook/&lt;token&gt; \
  -H "Content-Type: application/json" \
  -d '&#123;"event": "test"&#125;'</pre>
						{/snippet}
					</EmptyState>
				{:else}
					<div class="divide-y divide-border">
						{#each endpoints as ep (ep.id)}
							<button
								onclick={() => handleSelectEndpoint(ep)}
								class="w-full text-left px-4 py-3 transition-colors cursor-pointer
									{selectedEndpoint?.id === ep.id
									? 'bg-phosphor-glow border-l-2 border-l-phosphor'
									: 'hover:bg-surface-2 border-l-2 border-l-transparent'}"
							>
								<div class="flex items-center gap-2 mb-0.5">
									<span class="material-symbols-outlined text-sm text-text-dim">webhook</span>
									<span class="text-sm font-mono text-text-primary truncate flex-1 font-medium">{ep.label || ep.token.slice(0, 12)}</span>
									<span class="text-xs font-mono text-text-dim">({ep.request_count})</span>
								</div>
								<div class="flex items-center gap-2">
									<span class="text-[10px] font-mono text-text-dim truncate">{ep.token.slice(0, 12)}...</span>
									<span class="text-[10px] font-mono text-text-dim">{timeAgo(ep.created_at)}</span>
								</div>
							</button>
						{/each}
					</div>
				{/if}
			{/snippet}
		</FilterableList>
	{/snippet}

	{#snippet detail()}
		{#if selectedEndpoint}
			<div class="p-6 overflow-auto h-full">
				<div class="flex items-start justify-between mb-4">
					<div>
						<h3 class="text-lg font-display font-bold text-text-primary">{selectedEndpoint.label || 'Webhook endpoint'}</h3>
						<p class="text-xs font-mono text-text-dim mt-1">
							<span class="select-all">{selectedEndpoint.url || `/hook/${selectedEndpoint.token}`}</span>
						</p>
					</div>
					<button
						onclick={() => selectedEndpoint && handleDeleteEndpoint(selectedEndpoint)}
						class="px-3 py-1.5 text-xs font-mono text-error border border-error/30 rounded hover:bg-error/10"
					>
						Delete
					</button>
				</div>

				<div class="grid grid-cols-3 gap-4 mb-6">
					<div class="p-3 rounded-lg bg-surface border border-border">
						<p class="text-[10px] font-mono text-text-dim uppercase">Requests</p>
						<p class="text-lg font-display font-bold text-text-primary">{selectedEndpoint.request_count}</p>
					</div>
					<div class="p-3 rounded-lg bg-surface border border-border">
						<p class="text-[10px] font-mono text-text-dim uppercase">Methods</p>
						<p class="text-sm font-mono text-text-primary mt-1">{selectedEndpoint.allowed_methods.join(', ')}</p>
					</div>
					<div class="p-3 rounded-lg bg-surface border border-border">
						<p class="text-[10px] font-mono text-text-dim uppercase">Created</p>
						<p class="text-sm font-mono text-text-primary mt-1">{timeAgo(selectedEndpoint.created_at)}</p>
					</div>
				</div>

				<p class="text-sm font-mono text-text-dim">
					Select this endpoint in the sidebar or visit
					<a href="/projects/{projectId}/hooks/{selectedEndpoint.token}" class="text-phosphor hover:underline">
						the detail page
					</a> to see captured requests.
				</p>
			</div>
		{/if}
	{/snippet}

	{#snippet empty()}
		<EmptyState icon="webhook" title="Select an endpoint to view details" />
	{/snippet}
</SplitPane>

<CreateEndpointDialog {projectId} bind:open={showCreate} onCreate={handleEndpointCreated} />
