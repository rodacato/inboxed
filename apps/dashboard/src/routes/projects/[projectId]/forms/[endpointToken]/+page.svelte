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

	const projectId = $derived($page.params.projectId ?? '');
	const endpointToken = $derived($page.params.endpointToken ?? '');
	const realtime = getRealtimeStore();

	let endpoint = $state<HttpEndpoint | null>(null);
	let requests = $state<HttpRequestSummary[]>([]);
	let pagination = $state<Pagination | null>(null);
	let selectedDetail = $state<HttpRequestDetail | null>(null);
	let loading = $state(true);
	let loadingMore = $state(false);
	let activeTab = $state<'fields' | 'raw' | 'headers'>('fields');
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
		if (requests.length > 0) await selectRequest(requests[0].id);

		unsubscribe = realtime.subscribeToProject(pid, (msg) => {
			if (msg.type === 'request_captured' && msg.endpoint_id === endpoint?.id) {
				const req = msg.request as HttpRequestSummary;
				requests = [req, ...requests];
				if (endpoint) endpoint = { ...endpoint, request_count: endpoint.request_count + 1 };
			}
		});
	}

	async function selectRequest(id: string) {
		const res = await fetchRequest(projectId, endpointToken, id);
		selectedDetail = res.request;
		activeTab = 'fields';
	}

	const formFields = $derived.by(() => {
		if (!selectedDetail?.body) return [];
		const ct = selectedDetail.content_type ?? '';
		if (ct.includes('json')) {
			try {
				const obj = JSON.parse(selectedDetail.body);
				return Object.entries(obj).map(([k, v]) => ({ key: k, value: String(v) }));
			} catch {
				return [];
			}
		}
		if (ct.includes('form')) {
			try {
				const params = new URLSearchParams(selectedDetail.body);
				return [...params.entries()].map(([k, v]) => ({ key: k, value: v }));
			} catch {
				return [];
			}
		}
		return [];
	});

	async function loadMore() {
		if (!pagination?.has_more || !pagination.next_cursor) return;
		loadingMore = true;
		const res = await fetchRequests(projectId, endpointToken, { after: pagination.next_cursor });
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

	function formatBytes(bytes: number): string {
		if (bytes < 1024) return `${bytes} B`;
		return `${(bytes / 1024).toFixed(1)} KB`;
	}
</script>

<SplitPane showDetail={!!selectedDetail}>
	{#snippet list()}
		<FilterableList
			title={endpoint?.label || 'Submissions'}
			totalCount={pagination?.total_count}
			hasMore={pagination?.has_more ?? false}
			{loadingMore}
			onLoadMore={loadMore}
			{loading}
		>
			{#snippet items()}
				{#if requests.length === 0}
					<EmptyState icon="description" title="No submissions yet" description="Submit a form to see data here." />
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
									<span class="text-xs font-mono font-bold text-cyan">{req.method}</span>
									<span class="flex-1"></span>
									<span class="text-[10px] font-mono text-text-dim">{timeAgo(req.received_at)}</span>
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
				<div class="flex items-center gap-3 mb-4 text-xs font-mono text-text-dim">
					<span>{selectedDetail.method}</span>
					<span>{selectedDetail.ip_address}</span>
					<span>{formatBytes(selectedDetail.size_bytes)}</span>
					<span>{timeAgo(selectedDetail.received_at)}</span>
				</div>

				<div class="flex gap-1 mb-4 border-b border-border">
					{#each ['fields', 'raw', 'headers'] as tab (tab)}
						<button
							onclick={() => (activeTab = tab as typeof activeTab)}
							class="px-3 py-2 text-xs font-mono transition-colors border-b-2
								{activeTab === tab ? 'border-phosphor text-phosphor' : 'border-transparent text-text-dim hover:text-text-secondary'}"
						>
							{tab === 'fields' ? 'Fields' : tab === 'raw' ? 'Raw' : `Headers (${Object.keys(selectedDetail?.headers ?? {}).length})`}
						</button>
					{/each}
				</div>

				{#if activeTab === 'fields'}
					{#if formFields.length > 0}
						<div class="rounded-lg border border-border overflow-hidden">
							<table class="w-full text-sm">
								<thead class="bg-surface-2">
									<tr class="text-left text-xs font-mono text-text-dim uppercase">
										<th class="px-4 py-2">Field</th>
										<th class="px-4 py-2">Value</th>
									</tr>
								</thead>
								<tbody>
									{#each formFields as field (field.key)}
										<tr class="border-t border-border">
											<td class="px-4 py-2 font-mono text-text-secondary">{field.key}</td>
											<td class="px-4 py-2 font-mono text-text-primary break-all">{field.value}</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					{:else}
						<p class="text-sm font-mono text-text-dim">No form fields detected</p>
					{/if}
				{:else if activeTab === 'raw'}
					<pre class="p-4 rounded-lg bg-surface-2 border border-border text-sm font-mono text-text-primary overflow-auto max-h-96 whitespace-pre-wrap break-all">{selectedDetail.body ?? 'No body'}</pre>
				{:else}
					<HeadersTable headers={selectedDetail.headers} />
				{/if}
			</div>
		{/if}
	{/snippet}

	{#snippet empty()}
		<EmptyState icon="arrow_left" title="Select a submission to view" />
	{/snippet}
</SplitPane>
