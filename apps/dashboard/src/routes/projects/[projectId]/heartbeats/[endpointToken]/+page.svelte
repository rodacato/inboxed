<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import {
		fetchEndpoint,
		fetchRequests,
		deleteEndpoint
	} from '../../../../../features/hooks/hooks.service';
	import { getRealtimeStore } from '../../../../../features/realtime/realtime.store.svelte';
	import type {
		HttpEndpoint,
		HttpRequestSummary
	} from '../../../../../features/hooks/hooks.types';
	import type { Pagination } from '../../../../../features/projects/projects.types';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import HeartbeatStatusBadge from '../../../../../features/hooks/components/HeartbeatStatusBadge.svelte';

	const projectId = $derived($page.params.projectId ?? '');
	const endpointToken = $derived($page.params.endpointToken ?? '');
	const realtime = getRealtimeStore();

	let endpoint = $state<HttpEndpoint | null>(null);
	let requests = $state<HttpRequestSummary[]>([]);
	let pagination = $state<Pagination | null>(null);
	let loading = $state(true);
	let loadingMore = $state(false);
	let unsubscribe: (() => void) | undefined;

	$effect(() => {
		const pid = projectId;
		const token = endpointToken;
		if (!pid || !token) return;
		loading = true;
		endpoint = null;
		requests = [];
		unsubscribe?.();
		loadData(pid, token);
	});

	async function loadData(pid: string, token: string) {
		const [epRes, reqRes] = await Promise.all([
			fetchEndpoint(pid, token),
			fetchRequests(pid, token)
		]);
		if (pid !== projectId || token !== endpointToken) return;
		endpoint = epRes.endpoint;
		requests = reqRes.requests;
		pagination = reqRes.pagination;
		loading = false;

		unsubscribe = realtime.subscribeToProject(pid, (msg) => {
			if (msg.type === 'request_captured' && msg.endpoint_id === endpoint?.id) {
				const req = msg.request as HttpRequestSummary;
				requests = [req, ...requests];
				if (endpoint) endpoint = { ...endpoint, request_count: endpoint.request_count + 1, heartbeat_status: 'healthy', last_ping_at: req.received_at };
			}
			if (msg.type === 'heartbeat_status_changed' && msg.endpoint_id === endpoint?.id) {
				if (endpoint) {
					endpoint = { ...endpoint, heartbeat_status: msg.new_status as HttpEndpoint['heartbeat_status'] };
				}
			}
		});
	}

	async function handleDelete() {
		if (!endpoint) return;
		if (!confirm(`Delete heartbeat "${endpoint.label || endpoint.token.slice(0, 8)}"?`)) return;
		await deleteEndpoint(projectId, endpointToken);
		goto(`/projects/${projectId}/heartbeats`);
	}

	async function loadMore() {
		if (!pagination?.has_more || !pagination.next_cursor) return;
		loadingMore = true;
		const res = await fetchRequests(projectId, endpointToken, { after: pagination.next_cursor });
		requests = [...requests, ...res.requests];
		pagination = res.pagination;
		loadingMore = false;
	}

	function timeAgo(iso: string | null): string {
		if (!iso) return 'never';
		const diff = Date.now() - new Date(iso).getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 1) return 'just now';
		if (mins < 60) return `${mins}m ago`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h ago`;
		return `${Math.floor(hours / 24)}d ago`;
	}

	function formatInterval(seconds: number | null): string {
		if (!seconds) return '—';
		if (seconds < 60) return `${seconds}s`;
		if (seconds < 3600) return `${Math.round(seconds / 60)}m`;
		return `${Math.round(seconds / 3600)}h`;
	}
</script>

<div class="h-full overflow-auto">
	{#if loading}
		<div class="p-8"><p class="text-text-dim font-mono text-sm">Loading...</p></div>
	{:else if endpoint}
		<div class="p-6">
			<!-- Header -->
			<div class="flex items-start justify-between mb-6">
				<div>
					<div class="flex items-center gap-3 mb-1">
						<h2 class="text-xl font-display font-bold text-text-primary">{endpoint.label || 'Heartbeat'}</h2>
						<HeartbeatStatusBadge status={endpoint.heartbeat_status} />
					</div>
					<p class="text-xs font-mono text-text-dim select-all">{endpoint.url || `/hook/${endpoint.token}`}</p>
				</div>
				<button
					onclick={handleDelete}
					class="px-3 py-1.5 text-xs font-mono text-error border border-error/30 rounded hover:bg-error/10"
				>
					Delete
				</button>
			</div>

			<!-- Stats -->
			<div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
				<div class="p-3 rounded-lg bg-surface border border-border">
					<p class="text-[10px] font-mono text-text-dim uppercase">Status</p>
					<p class="mt-1"><HeartbeatStatusBadge status={endpoint.heartbeat_status} /></p>
				</div>
				<div class="p-3 rounded-lg bg-surface border border-border">
					<p class="text-[10px] font-mono text-text-dim uppercase">Expected</p>
					<p class="text-sm font-mono text-text-primary mt-1">every {formatInterval(endpoint.expected_interval_seconds)}</p>
				</div>
				<div class="p-3 rounded-lg bg-surface border border-border">
					<p class="text-[10px] font-mono text-text-dim uppercase">Last Ping</p>
					<p class="text-sm font-mono text-text-primary mt-1">{timeAgo(endpoint.last_ping_at)}</p>
				</div>
				<div class="p-3 rounded-lg bg-surface border border-border">
					<p class="text-[10px] font-mono text-text-dim uppercase">Total Pings</p>
					<p class="text-lg font-display font-bold text-text-primary">{endpoint.request_count}</p>
				</div>
			</div>

			<!-- Recent pings -->
			<h3 class="text-sm font-mono font-bold text-text-primary mb-3">Recent Pings</h3>
			{#if requests.length === 0}
				<EmptyState icon="favorite" title="No pings yet" description="Send a ping to start monitoring." />
			{:else}
				<div class="rounded-lg border border-border overflow-hidden mb-4">
					<table class="w-full text-sm">
						<thead class="bg-surface-2">
							<tr class="text-left text-xs font-mono text-text-dim uppercase">
								<th class="px-4 py-2">Method</th>
								<th class="px-4 py-2">IP</th>
								<th class="px-4 py-2">Size</th>
								<th class="px-4 py-2">Received</th>
							</tr>
						</thead>
						<tbody>
							{#each requests as req (req.id)}
								<tr class="border-t border-border hover:bg-surface-2/50">
									<td class="px-4 py-2 font-mono text-text-primary">{req.method}</td>
									<td class="px-4 py-2 font-mono text-text-secondary">{req.ip_address}</td>
									<td class="px-4 py-2 font-mono text-text-secondary">{req.size_bytes} B</td>
									<td class="px-4 py-2 font-mono text-text-secondary">{timeAgo(req.received_at)}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
				{#if pagination?.has_more}
					<button
						onclick={loadMore}
						disabled={loadingMore}
						class="w-full py-2 text-xs font-mono text-text-secondary hover:text-text-primary border border-border rounded"
					>
						{loadingMore ? 'Loading...' : 'Load more'}
					</button>
				{/if}
			{/if}
		</div>
	{/if}
</div>
