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
	import HeartbeatStatusBadge from '../../../../features/hooks/components/HeartbeatStatusBadge.svelte';
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
		const res = await fetchEndpoints(pid, { type: 'heartbeat' });
		if (pid !== projectId) return;
		endpoints = res.endpoints;
		pagination = res.pagination;
		loading = false;

		unsubscribe = realtime.subscribeToProject(pid, (msg) => {
			if (msg.type === 'heartbeat_status_changed') {
				endpoints = endpoints.map((e) =>
					e.id === msg.endpoint_id
						? { ...e, heartbeat_status: msg.new_status as HttpEndpoint['heartbeat_status'] }
						: e
				);
				if (selectedEndpoint && selectedEndpoint.id === msg.endpoint_id) {
					selectedEndpoint = { ...selectedEndpoint, heartbeat_status: msg.new_status as HttpEndpoint['heartbeat_status'] };
				}
				const ep = endpoints.find((e) => e.id === msg.endpoint_id);
				if (msg.new_status === 'down') {
					toastStore.add({
						type: 'error',
						title: 'Heartbeat down',
						description: `${ep?.label ?? 'Unknown'} missed expected ping`,
						duration: 0
					});
				} else if (msg.new_status === 'healthy' && (msg.previous_status === 'down' || msg.previous_status === 'late')) {
					toastStore.add({
						type: 'success',
						title: 'Heartbeat recovered',
						description: `${ep?.label ?? 'Unknown'} is healthy again`
					});
				}
			} else if (msg.type === 'request_captured' && msg.endpoint_type === 'heartbeat') {
				endpoints = endpoints.map((e) =>
					e.id === msg.endpoint_id ? { ...e, request_count: e.request_count + 1 } : e
				);
			}
		});
	}

	function handleEndpointCreated(ep: HttpEndpoint) {
		endpoints = [ep, ...endpoints];
		selectedEndpoint = ep;
		toastStore.add({ type: 'success', title: 'Heartbeat created', description: ep.label ?? ep.token.slice(0, 8) });
	}

	function formatInterval(seconds: number | null): string {
		if (!seconds) return '—';
		if (seconds < 60) return `${seconds}s`;
		if (seconds < 3600) return `${Math.round(seconds / 60)}m`;
		return `${Math.round(seconds / 3600)}h`;
	}

	function timeAgo(iso: string | null): string {
		if (!iso) return 'never';
		const diff = Date.now() - new Date(iso).getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 1) return 'now';
		if (mins < 60) return `${mins}m ago`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h ago`;
		return `${Math.floor(hours / 24)}d ago`;
	}
</script>

<SplitPane showDetail={!!selectedEndpoint}>
	{#snippet list()}
		<FilterableList title="Heartbeats" totalCount={pagination?.total_count} {loading}>
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
						icon="favorite"
						title="No heartbeat monitors yet"
						description="Create a heartbeat endpoint and ping it from your cron job."
					>
						{#snippet content()}
							<pre class="text-xs font-mono text-text-secondary bg-surface-2 p-3 rounded mt-2 text-left"># In your crontab:
*/5 * * * * curl -s https://your-domain/hook/&lt;token&gt;</pre>
						{/snippet}
					</EmptyState>
				{:else}
					<div class="divide-y divide-border">
						{#each endpoints as ep (ep.id)}
							<button
								onclick={() => (selectedEndpoint = ep)}
								class="w-full text-left px-4 py-3 transition-colors cursor-pointer
									{selectedEndpoint?.id === ep.id
									? 'bg-phosphor-glow border-l-2 border-l-phosphor'
									: 'hover:bg-surface-2 border-l-2 border-l-transparent'}"
							>
								<div class="flex items-center gap-2 mb-1">
									<span class="material-symbols-outlined text-sm text-text-dim">favorite</span>
									<span class="text-sm font-mono text-text-primary truncate flex-1 font-medium">{ep.label || ep.token.slice(0, 12)}</span>
									<HeartbeatStatusBadge status={ep.heartbeat_status} />
								</div>
								<div class="flex items-center gap-2 text-[10px] font-mono text-text-dim">
									<span>every {formatInterval(ep.expected_interval_seconds)}</span>
									<span>last ping: {timeAgo(ep.last_ping_at)}</span>
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
						<div class="flex items-center gap-3">
							<h3 class="text-lg font-display font-bold text-text-primary">{selectedEndpoint.label || 'Heartbeat'}</h3>
							<HeartbeatStatusBadge status={selectedEndpoint.heartbeat_status} />
						</div>
						<p class="text-xs font-mono text-text-dim mt-1 select-all">{selectedEndpoint.url || `/hook/${selectedEndpoint.token}`}</p>
					</div>
					<a
						href="/projects/{projectId}/heartbeats/{selectedEndpoint.token}"
						class="px-3 py-1.5 text-xs font-mono text-phosphor border border-phosphor/30 rounded hover:bg-phosphor-glow"
					>
						View pings
					</a>
				</div>

				<div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
					<div class="p-3 rounded-lg bg-surface border border-border">
						<p class="text-[10px] font-mono text-text-dim uppercase">Status</p>
						<p class="mt-1"><HeartbeatStatusBadge status={selectedEndpoint.heartbeat_status} /></p>
					</div>
					<div class="p-3 rounded-lg bg-surface border border-border">
						<p class="text-[10px] font-mono text-text-dim uppercase">Interval</p>
						<p class="text-sm font-mono text-text-primary mt-1">every {formatInterval(selectedEndpoint.expected_interval_seconds)}</p>
					</div>
					<div class="p-3 rounded-lg bg-surface border border-border">
						<p class="text-[10px] font-mono text-text-dim uppercase">Last Ping</p>
						<p class="text-sm font-mono text-text-primary mt-1">{timeAgo(selectedEndpoint.last_ping_at)}</p>
					</div>
					<div class="p-3 rounded-lg bg-surface border border-border">
						<p class="text-[10px] font-mono text-text-dim uppercase">Total Pings</p>
						<p class="text-lg font-display font-bold text-text-primary">{selectedEndpoint.request_count}</p>
					</div>
				</div>

				<div class="p-4 rounded-lg bg-surface-2 border border-border">
					<h4 class="text-sm font-mono font-bold text-text-primary mb-2">Setup</h4>
					<pre class="text-xs font-mono text-text-secondary">
# Add to crontab ({formatInterval(selectedEndpoint.expected_interval_seconds)} interval):
*/{selectedEndpoint.expected_interval_seconds ? Math.max(1, Math.round(selectedEndpoint.expected_interval_seconds / 60)) : 5} * * * * curl -s {selectedEndpoint.url || `/hook/${selectedEndpoint.token}`}</pre>
				</div>
			</div>
		{/if}
	{/snippet}

	{#snippet empty()}
		<EmptyState icon="favorite" title="Select a heartbeat to view details" />
	{/snippet}
</SplitPane>

<CreateEndpointDialog {projectId} bind:open={showCreate} onCreate={handleEndpointCreated} />
