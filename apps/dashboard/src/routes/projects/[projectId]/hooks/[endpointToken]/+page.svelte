<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import {
		fetchEndpoint,
		fetchRequests,
		fetchRequest,
		deleteRequest,
		purgeEndpointRequests,
		deleteEndpoint
	} from '../../../../../features/hooks/hooks.service';
	import { getRealtimeStore } from '../../../../../features/realtime/realtime.store.svelte';
	import { toastStore } from '$lib/stores/toast.store.svelte';
	import type {
		HttpEndpoint,
		HttpRequestSummary,
		HttpRequestDetail
	} from '../../../../../features/hooks/hooks.types';
	import type { Pagination } from '../../../../../features/projects/projects.types';
	import SplitPane from '$lib/components/SplitPane.svelte';
	import FilterableList from '$lib/components/FilterableList.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import HeadersTable from '../../../../../features/hooks/components/HeadersTable.svelte';
	import RequestBodyViewer from '../../../../../features/hooks/components/RequestBodyViewer.svelte';

	const projectId = $derived($page.params.projectId ?? '');
	const endpointToken = $derived($page.params.endpointToken ?? '');
	const realtime = getRealtimeStore();

	let endpoint = $state<HttpEndpoint | null>(null);
	let requests = $state<HttpRequestSummary[]>([]);
	let pagination = $state<Pagination | null>(null);
	let selectedDetail = $state<HttpRequestDetail | null>(null);
	let loading = $state(true);
	let loadingMore = $state(false);
	let activeTab = $state<'body' | 'headers'>('body');
	let unsubscribe: (() => void) | undefined;

	$effect(() => {
		const pid = projectId;
		const token = endpointToken;
		if (!pid || !token) return;
		loading = true;
		endpoint = null;
		requests = [];
		selectedDetail = null;
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

		if (requests.length > 0) {
			await selectRequest(requests[0].id);
		}

		unsubscribe = realtime.subscribeToProject(pid, (msg) => {
			if (msg.type === 'request_captured' && msg.endpoint_id === endpoint?.id) {
				const req = msg.request as HttpRequestSummary;
				requests = [req, ...requests];
				if (endpoint) {
					endpoint = { ...endpoint, request_count: endpoint.request_count + 1 };
				}
				toastStore.add({
					type: 'success',
					title: `${req.method} request captured`,
					description: req.path || endpoint?.label || ''
				});
			} else if (msg.type === 'requests_purged' && msg.endpoint_id === endpoint?.id) {
				requests = [];
				selectedDetail = null;
				if (endpoint) endpoint = { ...endpoint, request_count: 0 };
			}
		});
	}

	async function selectRequest(id: string) {
		if (!endpoint) return;
		const res = await fetchRequest(projectId, endpointToken, id);
		selectedDetail = res.request;
		activeTab = 'body';
	}

	async function handleDeleteRequest() {
		if (!selectedDetail || !endpoint) return;
		if (!confirm('Delete this request?')) return;
		await deleteRequest(projectId, endpointToken, selectedDetail.id);
		requests = requests.filter((r) => r.id !== selectedDetail!.id);
		endpoint = { ...endpoint, request_count: Math.max(0, endpoint.request_count - 1) };
		selectedDetail = requests.length > 0 ? null : null;
		if (requests.length > 0) {
			await selectRequest(requests[0].id);
		}
	}

	async function handlePurge() {
		if (!endpoint) return;
		if (!confirm('Delete ALL captured requests?')) return;
		await purgeEndpointRequests(projectId, endpointToken);
		requests = [];
		selectedDetail = null;
		endpoint = { ...endpoint, request_count: 0 };
		toastStore.add({ type: 'info', title: 'All requests purged' });
	}

	async function handleDeleteEndpoint() {
		if (!endpoint) return;
		if (!confirm(`Delete endpoint "${endpoint.label || endpoint.token.slice(0, 8)}" and ALL its data?`)) return;
		await deleteEndpoint(projectId, endpointToken);
		goto(`/projects/${projectId}/hooks`);
	}

	async function loadMore() {
		if (!pagination?.has_more || !pagination.next_cursor) return;
		loadingMore = true;
		const res = await fetchRequests(projectId, endpointToken, {
			after: pagination.next_cursor
		});
		requests = [...requests, ...res.requests];
		pagination = res.pagination;
		loadingMore = false;
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

	function methodColor(method: string): string {
		switch (method) {
			case 'GET': return 'text-phosphor';
			case 'POST': return 'text-cyan';
			case 'PUT': return 'text-amber';
			case 'PATCH': return 'text-amber';
			case 'DELETE': return 'text-error';
			default: return 'text-text-secondary';
		}
	}

	function formatBytes(bytes: number): string {
		if (bytes < 1024) return `${bytes} B`;
		if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
		return `${(bytes / 1048576).toFixed(1)} MB`;
	}
</script>

<SplitPane showDetail={!!selectedDetail}>
	{#snippet list()}
		<FilterableList
			title={endpoint?.label || 'Requests'}
			totalCount={pagination?.total_count}
			hasMore={pagination?.has_more ?? false}
			{loadingMore}
			onLoadMore={loadMore}
			{loading}
		>
			{#snippet headerActions()}
				{#if requests.length > 0}
					<button
						onclick={handlePurge}
						class="px-2 py-1 text-xs font-mono text-text-dim hover:text-error"
						title="Purge all"
					>
						<span class="material-symbols-outlined text-sm">delete_sweep</span>
					</button>
				{/if}
			{/snippet}
			{#snippet items()}
				{#if requests.length === 0}
					<EmptyState
						icon="webhook"
						title="No requests captured yet"
						description="Send a request to this endpoint to see it here."
					>
						{#snippet content()}
							{#if endpoint}
								<pre class="text-xs font-mono text-text-secondary bg-surface-2 p-3 rounded mt-2 text-left">curl -X POST {endpoint.url || `/hook/${endpoint.token}`} \
  -H "Content-Type: application/json" \
  -d '{"{"}test": true{"}"}'</pre>
							{/if}
						{/snippet}
					</EmptyState>
				{:else}
					<div class="divide-y divide-border">
						{#each requests as req (req.id)}
							<button
								onclick={() => selectRequest(req.id)}
								class="w-full text-left px-4 py-3 transition-colors cursor-pointer
									{selectedDetail?.id === req.id
									? 'bg-phosphor-glow border-l-2 border-l-phosphor'
									: 'hover:bg-surface-2 border-l-2 border-l-transparent'}"
							>
								<div class="flex items-center gap-2 mb-0.5">
									<span class="text-xs font-mono font-bold {methodColor(req.method)}">{req.method}</span>
									{#if req.path}
										<span class="text-xs font-mono text-text-secondary truncate flex-1">/{req.path}</span>
									{:else}
										<span class="flex-1"></span>
									{/if}
									<span class="text-[10px] font-mono text-text-dim shrink-0">{timeAgo(req.received_at)}</span>
								</div>
								<div class="flex items-center gap-3 text-[10px] font-mono text-text-dim">
									{#if req.ip_address}<span>{req.ip_address}</span>{/if}
									<span>{formatBytes(req.size_bytes)}</span>
								</div>
							</button>
						{/each}
					</div>
				{/if}
			{/snippet}
		</FilterableList>
	{/snippet}

	{#snippet detail()}
		{#if selectedDetail}
			<div class="p-6 overflow-auto h-full">
				<div class="flex items-start justify-between mb-4">
					<div>
						<div class="flex items-center gap-2">
							<span class="text-sm font-mono font-bold {methodColor(selectedDetail.method)}">{selectedDetail.method}</span>
							{#if selectedDetail.path}
								<span class="text-sm font-mono text-text-primary">/{selectedDetail.path}</span>
							{/if}
						</div>
						<div class="flex items-center gap-3 mt-1 text-xs font-mono text-text-dim">
							<span>{selectedDetail.ip_address}</span>
							<span>{formatBytes(selectedDetail.size_bytes)}</span>
							<span>{timeAgo(selectedDetail.received_at)}</span>
						</div>
					</div>
					<button
						onclick={handleDeleteRequest}
						class="px-2 py-1 text-xs font-mono text-text-dim hover:text-error"
						title="Delete request"
					>
						<span class="material-symbols-outlined text-sm">delete</span>
					</button>
				</div>

				<div class="flex gap-1 mb-4 border-b border-border">
					<button
						onclick={() => (activeTab = 'body')}
						class="px-3 py-2 text-xs font-mono transition-colors border-b-2
							{activeTab === 'body' ? 'border-phosphor text-phosphor' : 'border-transparent text-text-dim hover:text-text-secondary'}"
					>
						Body
					</button>
					<button
						onclick={() => (activeTab = 'headers')}
						class="px-3 py-2 text-xs font-mono transition-colors border-b-2
							{activeTab === 'headers' ? 'border-phosphor text-phosphor' : 'border-transparent text-text-dim hover:text-text-secondary'}"
					>
						Headers ({Object.keys(selectedDetail.headers).length})
					</button>
				</div>

				{#if activeTab === 'body'}
					<RequestBodyViewer body={selectedDetail.body} contentType={selectedDetail.content_type} />
				{:else}
					<HeadersTable headers={selectedDetail.headers} />
				{/if}
			</div>
		{/if}
	{/snippet}

	{#snippet empty()}
		<EmptyState icon="arrow_left" title="Select a request to view details" />
	{/snippet}
</SplitPane>
