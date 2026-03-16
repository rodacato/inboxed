<script lang="ts">
	import { page } from '$app/stores';
	import { fetchEndpoints } from '../../../../features/hooks/hooks.service';
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
	let copied = $state(false);
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
		const res = await fetchEndpoints(pid, { type: 'form' });
		if (pid !== projectId) return;
		endpoints = res.endpoints;
		pagination = res.pagination;
		loading = false;

		unsubscribe = realtime.subscribeToProject(pid, (msg) => {
			if (msg.type === 'request_captured' && msg.endpoint_type === 'form') {
				endpoints = endpoints.map((e) =>
					e.id === msg.endpoint_id ? { ...e, request_count: e.request_count + 1 } : e
				);
				const ep = endpoints.find((e) => e.id === msg.endpoint_id);
				if (ep) {
					toastStore.add({
						type: 'success',
						title: 'Form submission captured',
						description: ep.label ?? ep.token.slice(0, 8)
					});
				}
			}
		});
	}

	function handleEndpointCreated(ep: HttpEndpoint) {
		endpoints = [ep, ...endpoints];
		selectedEndpoint = ep;
		toastStore.add({ type: 'success', title: 'Form endpoint created', description: ep.label ?? ep.token.slice(0, 8) });
	}

	function formSnippet(ep: HttpEndpoint): string {
		const url = ep.url || `/hook/${ep.token}`;
		return `<form action="${url}" method="POST">
  <input name="email" type="email" placeholder="Email" />
  <textarea name="message" placeholder="Message"></textarea>
  <button type="submit">Send</button>
</form>`;
	}

	function copySnippet(ep: HttpEndpoint) {
		navigator.clipboard.writeText(formSnippet(ep));
		copied = true;
		setTimeout(() => (copied = false), 2000);
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
		<FilterableList title="Forms" totalCount={pagination?.total_count} {loading}>
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
						icon="description"
						title="No form endpoints yet"
						description="Create a form endpoint and point your HTML form at it."
					>
						{#snippet content()}
							<pre class="text-xs font-mono text-text-secondary bg-surface-2 p-3 rounded mt-2 text-left">&lt;form action="https://your-domain/hook/&lt;token&gt;" method="POST"&gt;
  &lt;input name="email" /&gt;
  &lt;button type="submit"&gt;Send&lt;/button&gt;
&lt;/form&gt;</pre>
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
								<div class="flex items-center gap-2 mb-0.5">
									<span class="material-symbols-outlined text-sm text-text-dim">description</span>
									<span class="text-sm font-mono text-text-primary truncate flex-1 font-medium">{ep.label || ep.token.slice(0, 12)}</span>
									<span class="text-xs font-mono text-text-dim">({ep.request_count})</span>
								</div>
								<div class="flex items-center gap-2 text-[10px] font-mono text-text-dim">
									<span>{ep.response_mode ?? 'json'}</span>
									<span>{timeAgo(ep.created_at)}</span>
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
						<h3 class="text-lg font-display font-bold text-text-primary">{selectedEndpoint.label || 'Form endpoint'}</h3>
						<p class="text-xs font-mono text-text-dim mt-1 select-all">{selectedEndpoint.url || `/hook/${selectedEndpoint.token}`}</p>
					</div>
					<a
						href="/projects/{projectId}/forms/{selectedEndpoint.token}"
						class="px-3 py-1.5 text-xs font-mono text-phosphor border border-phosphor/30 rounded hover:bg-phosphor-glow"
					>
						View submissions
					</a>
				</div>

				<div class="grid grid-cols-2 gap-4 mb-6">
					<div class="p-3 rounded-lg bg-surface border border-border">
						<p class="text-[10px] font-mono text-text-dim uppercase">Submissions</p>
						<p class="text-lg font-display font-bold text-text-primary">{selectedEndpoint.request_count}</p>
					</div>
					<div class="p-3 rounded-lg bg-surface border border-border">
						<p class="text-[10px] font-mono text-text-dim uppercase">Response</p>
						<p class="text-sm font-mono text-text-primary mt-1">{selectedEndpoint.response_mode ?? 'json'}</p>
					</div>
				</div>

				<div class="mb-2 flex items-center justify-between">
					<h4 class="text-sm font-mono font-bold text-text-primary">HTML Snippet</h4>
					<button
						onclick={() => selectedEndpoint && copySnippet(selectedEndpoint)}
						class="px-2 py-1 text-xs font-mono text-text-secondary hover:text-text-primary border border-border rounded"
					>
						{copied ? 'Copied!' : 'Copy'}
					</button>
				</div>
				<pre class="text-xs font-mono text-text-secondary bg-surface-2 p-4 rounded-lg border border-border overflow-auto">{formSnippet(selectedEndpoint)}</pre>
			</div>
		{/if}
	{/snippet}

	{#snippet empty()}
		<EmptyState icon="description" title="Select a form to view details" />
	{/snippet}
</SplitPane>

<CreateEndpointDialog {projectId} bind:open={showCreate} onCreate={handleEndpointCreated} />
