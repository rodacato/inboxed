<script lang="ts">
	import { page } from '$app/stores';
	import {
		fetchEndpoints,
		fetchProjectRequests,
		fetchProjectRequest
	} from '../../../../features/hooks/hooks.service';
	import { getRealtimeStore } from '../../../../features/realtime/realtime.store.svelte';
	import { toastStore } from '$lib/stores/toast.store.svelte';
	import type {
		HttpEndpoint,
		HttpRequestSummary,
		HttpRequestDetail
	} from '../../../../features/hooks/hooks.types';
	import type { Pagination } from '../../../../features/projects/projects.types';
	import SplitPane from '$lib/components/SplitPane.svelte';
	import FilterableList from '$lib/components/FilterableList.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';

	const projectId = $derived($page.params.projectId ?? '');
	const realtime = getRealtimeStore();

	let endpoints = $state<HttpEndpoint[]>([]);
	let allRequests = $state<HttpRequestSummary[]>([]);
	let pagination = $state<Pagination | null>(null);
	let loading = $state(true);
	let selectedRequest = $state<HttpRequestDetail | null>(null);
	let loadingDetail = $state(false);
	let unsubscribe: (() => void) | undefined;

	// Type filter toggles — all active by default
	let activeTypes = $state<Set<string>>(new Set(['webhook', 'form', 'heartbeat']));

	const typeConfig: { type: string; label: string; icon: string; color: string; activeClass: string }[] = [
		{ type: 'webhook', label: 'Webhooks', icon: 'webhook', color: 'text-phosphor', activeClass: 'bg-phosphor/15 border-phosphor text-phosphor' },
		{ type: 'form', label: 'Forms', icon: 'description', color: 'text-cyan', activeClass: 'bg-cyan/15 border-cyan text-cyan' },
		{ type: 'heartbeat', label: 'Heartbeats', icon: 'favorite', color: 'text-error', activeClass: 'bg-error/15 border-error text-error' }
	];

	const typeIcons: Record<string, string> = {
		webhook: 'webhook',
		form: 'description',
		heartbeat: 'favorite'
	};

	const typeColors: Record<string, string> = {
		webhook: 'text-phosphor',
		form: 'text-cyan',
		heartbeat: 'text-error'
	};

	// Filter requests by active types
	const filteredRequests = $derived(
		allRequests.filter((r) => !r.endpoint || activeTypes.has(r.endpoint.endpoint_type))
	);

	// Count per type for the pills
	const typeCounts = $derived(() => {
		const counts: Record<string, number> = { webhook: 0, form: 0, heartbeat: 0 };
		for (const ep of endpoints) {
			counts[ep.endpoint_type] = (counts[ep.endpoint_type] ?? 0) + ep.request_count;
		}
		return counts;
	});

	function toggleType(type: string) {
		const next = new Set(activeTypes);
		if (next.has(type)) {
			// Don't allow deactivating all
			if (next.size > 1) next.delete(type);
		} else {
			next.add(type);
		}
		activeTypes = next;
	}

	$effect(() => {
		const pid = projectId;
		if (!pid) return;
		allRequests = [];
		endpoints = [];
		loading = true;
		selectedRequest = null;
		activeTypes = new Set(['webhook', 'form', 'heartbeat']);
		unsubscribe?.();

		loadData(pid);
	});

	async function loadData(pid: string) {
		const [endpointsRes, requestsRes] = await Promise.all([
			fetchEndpoints(pid),
			fetchProjectRequests(pid)
		]);
		if (pid !== projectId) return;
		endpoints = endpointsRes.endpoints;
		allRequests = requestsRes.requests;
		pagination = requestsRes.pagination;
		loading = false;

		unsubscribe = realtime.subscribeToProject(pid, (msg) => {
			if (msg.type === 'request_captured') {
				const req = msg.request as HttpRequestSummary & { endpoint?: { token: string; label: string | null; endpoint_type: string } };
				if (req) {
					const ep = endpoints.find((e) => e.id === (msg.endpoint_id as string));
					const enriched: HttpRequestSummary = {
						...req,
						endpoint: req.endpoint ?? (ep ? { token: ep.token, label: ep.label, endpoint_type: ep.endpoint_type } : undefined)
					};
					allRequests = [enriched, ...allRequests];
					if (ep) {
						endpoints = endpoints.map((e) =>
							e.id === ep.id ? { ...e, request_count: e.request_count + 1 } : e
						);
					}
					toastStore.add({
						type: 'success',
						title: `${req.method ?? 'POST'} request captured`,
						description: ep?.label ?? ep?.token.slice(0, 8) ?? 'endpoint'
					});
				}
			} else if (msg.type === 'endpoint_created') {
				const ep = msg.endpoint as HttpEndpoint;
				if (ep) {
					endpoints = [{ ...ep, request_count: 0, url: '', allowed_methods: ['POST'], allowed_ips: [], max_body_bytes: 262144, response_mode: null, response_redirect_url: null, expected_interval_seconds: null, heartbeat_status: null, last_ping_at: null, status_changed_at: null, description: null, created_at: new Date().toISOString(), updated_at: new Date().toISOString() }, ...endpoints];
				}
			} else if (msg.type === 'endpoint_deleted') {
				endpoints = endpoints.filter((e) => e.id !== msg.endpoint_id);
			}
		});
	}

	async function handleSelectRequest(req: HttpRequestSummary) {
		loadingDetail = true;
		try {
			const res = await fetchProjectRequest(projectId, req.id);
			selectedRequest = res.request;
		} catch {
			toastStore.add({ type: 'error', title: 'Failed to load request' });
		} finally {
			loadingDetail = false;
		}
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

	async function copyValue(text: string) {
		await navigator.clipboard.writeText(text);
		toastStore.add({ type: 'success', title: 'Copied to clipboard' });
	}

	function formatBody(body: string | null, contentType: string | null): string {
		if (!body) return '';
		if (contentType?.includes('json')) {
			try { return JSON.stringify(JSON.parse(body), null, 2); } catch { /* not valid json */ }
		}
		return body;
	}

	function formatSize(bytes: number): string {
		if (bytes < 1024) return `${bytes}B`;
		return `${(bytes / 1024).toFixed(1)}KB`;
	}
</script>

<SplitPane showDetail={!!selectedRequest}>
	{#snippet list()}
		<FilterableList title="Hooks" totalCount={pagination?.total_count} {loading}>
			{#snippet subHeader()}
				<div class="inline-flex border border-border rounded-md overflow-hidden divide-x divide-border">
					{#each typeConfig as tc (tc.type)}
						{@const count = typeCounts()[tc.type] ?? 0}
						{@const isActive = activeTypes.has(tc.type)}
						{#if endpoints.some((e) => e.endpoint_type === tc.type)}
							<button
								onclick={() => toggleType(tc.type)}
								class="flex items-center gap-1 px-2.5 py-1 text-[10px] font-mono font-medium transition-all
									{isActive ? tc.activeClass : 'text-text-dim opacity-60 hover:opacity-100'}"
							>
								<span class="material-symbols-outlined text-xs">{tc.icon}</span>
								{tc.label}
								{#if count > 0}
									<span class="ml-0.5">{count}</span>
								{/if}
							</button>
						{/if}
					{/each}
				</div>
			{/snippet}
			{#snippet items()}
				{#if filteredRequests.length === 0 && !loading}
					<EmptyState
						icon="webhook"
						title="No requests yet"
						description={endpoints.length === 0
							? 'Create an endpoint to start catching HTTP requests.'
							: 'Send a request to one of your endpoints to see it here.'}
					/>
				{:else}
					<div class="divide-y divide-border">
						{#each filteredRequests as req (req.id)}
							<button
								onclick={() => handleSelectRequest(req)}
								class="w-full text-left px-4 py-3 transition-colors cursor-pointer
									{selectedRequest?.id === req.id
									? 'bg-phosphor-glow border-l-2 border-l-phosphor'
									: 'hover:bg-surface-2 border-l-2 border-l-transparent'}"
							>
								<div class="flex items-center gap-2 mb-0.5">
									<span class="px-1.5 py-0.5 text-[10px] font-mono font-bold bg-surface-2 border border-border rounded text-text-primary">
										{req.method}
									</span>
									{#if req.endpoint}
										<span class="material-symbols-outlined text-xs {typeColors[req.endpoint.endpoint_type] ?? 'text-text-dim'}">{typeIcons[req.endpoint.endpoint_type] ?? 'link'}</span>
										<span class="text-sm font-mono text-text-primary truncate flex-1">{req.endpoint.label || req.endpoint.token.slice(0, 12)}</span>
									{:else}
										<span class="text-sm font-mono text-text-primary truncate flex-1">{req.path || '/'}</span>
									{/if}
									<span class="text-[10px] font-mono text-text-dim shrink-0">{formatSize(req.size_bytes)}</span>
									<span class="text-[10px] font-mono text-text-dim shrink-0">{timeAgo(req.received_at)}</span>
								</div>
								{#if req.content_type}
									<div class="text-[10px] font-mono text-text-dim truncate pl-8">{req.content_type}</div>
								{/if}
							</button>
						{/each}
					</div>
				{/if}
			{/snippet}
		</FilterableList>
	{/snippet}

	{#snippet detail()}
		{#if selectedRequest}
			<div class="p-6 overflow-auto h-full">
				{#if loadingDetail}
					<p class="text-text-dim font-mono text-sm">Loading...</p>
				{:else}
					<!-- Header -->
					<div class="mb-4">
						<div class="flex items-center gap-2 mb-1">
							<span class="px-2 py-0.5 text-xs font-mono font-bold bg-surface-2 border border-border rounded text-text-primary">
								{selectedRequest.method}
							</span>
							{#if selectedRequest.endpoint}
								<span class="material-symbols-outlined text-sm {typeColors[selectedRequest.endpoint.endpoint_type] ?? 'text-text-dim'}">{typeIcons[selectedRequest.endpoint.endpoint_type] ?? 'link'}</span>
								<span class="text-sm font-mono text-text-secondary">{selectedRequest.endpoint.label || selectedRequest.endpoint.endpoint_type}</span>
							{/if}
						</div>
						{#if selectedRequest.endpoint?.url}
						<p class="text-xs font-mono text-text-dim mt-1">{selectedRequest.endpoint.url}{selectedRequest.path ? `/${selectedRequest.path}` : ''}{selectedRequest.query_string ? `?${selectedRequest.query_string}` : ''}</p>
					{:else}
						<p class="text-xs font-mono text-text-dim mt-1">{selectedRequest.path || '/'}{selectedRequest.query_string ? `?${selectedRequest.query_string}` : ''}</p>
					{/if}
						<p class="text-[10px] font-mono text-text-dim mt-1">
							{selectedRequest.ip_address} • {formatSize(selectedRequest.size_bytes)} • {timeAgo(selectedRequest.received_at)}
						</p>
					</div>

					<!-- Headers -->
					{#if selectedRequest.headers && Object.keys(selectedRequest.headers).length > 0}
						<div class="mb-4">
							<div class="flex items-center justify-between mb-2">
								<h4 class="text-xs font-mono text-text-dim uppercase">Headers</h4>
								<button onclick={() => copyValue(Object.entries(selectedRequest.headers).map(([k, v]) => `${k}: ${v}`).join('\n'))} class="text-text-dim hover:text-text-primary transition-colors" title="Copy headers">
									<span class="material-symbols-outlined text-sm">content_copy</span>
								</button>
							</div>
							<div class="bg-surface-2 border border-border rounded overflow-hidden">
								<table class="w-full text-xs font-mono">
									<tbody>
										{#each Object.entries(selectedRequest.headers) as [key, val]}
											<tr class="border-b border-border last:border-0">
												<td class="px-3 py-1.5 text-text-secondary whitespace-nowrap align-top font-medium">{key}</td>
												<td class="px-3 py-1.5 text-text-primary break-all">{val}</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
						</div>
					{/if}

					<!-- Query Params -->
					{#if selectedRequest.query_string}
						{@const params = new URLSearchParams(selectedRequest.query_string)}
						<div class="mb-4">
							<div class="flex items-center justify-between mb-2">
								<h4 class="text-xs font-mono text-text-dim uppercase">Query params</h4>
								<button onclick={() => copyValue(selectedRequest.query_string ?? '')} class="text-text-dim hover:text-text-primary transition-colors" title="Copy query string">
									<span class="material-symbols-outlined text-sm">content_copy</span>
								</button>
							</div>
							<div class="bg-surface-2 border border-border rounded overflow-hidden">
								<table class="w-full text-xs font-mono">
									<tbody>
										{#each [...params.entries()] as [key, val]}
											<tr class="border-b border-border last:border-0">
												<td class="px-3 py-1.5 text-text-secondary whitespace-nowrap align-top font-medium">{key}</td>
												<td class="px-3 py-1.5 text-text-primary break-all">{val}</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
						</div>
					{/if}

					<!-- Body -->
					{#if selectedRequest.body}
						<div>
							<div class="flex items-center justify-between mb-2">
								<h4 class="text-xs font-mono text-text-dim uppercase">Body</h4>
								<button onclick={() => copyValue(selectedRequest.body ?? '')} class="text-text-dim hover:text-text-primary transition-colors" title="Copy body">
									<span class="material-symbols-outlined text-sm">content_copy</span>
								</button>
							</div>
							<pre class="bg-surface-2 border border-border rounded px-3 py-2 text-xs font-mono text-text-primary overflow-x-auto whitespace-pre-wrap break-all max-h-96">{formatBody(selectedRequest.body, selectedRequest.content_type)}</pre>
						</div>
					{/if}
				{/if}
			</div>
		{/if}
	{/snippet}

	{#snippet empty()}
		<EmptyState icon="webhook" title="Select a request to view details" />
	{/snippet}
</SplitPane>
