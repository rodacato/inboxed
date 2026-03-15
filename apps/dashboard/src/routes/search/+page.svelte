<script lang="ts">
	import { searchEmails } from '../../features/search/search.service';
	import type { SearchResult } from '../../features/search/search.types';
	import type { Pagination } from '../../features/projects/projects.types';

	let query = $state('');
	let results = $state<SearchResult[]>([]);
	let pagination = $state<Pagination | null>(null);
	let loading = $state(false);
	let searched = $state(false);
	let debounceTimer: ReturnType<typeof setTimeout>;

	function handleInput() {
		clearTimeout(debounceTimer);
		debounceTimer = setTimeout(doSearch, 300);
	}

	async function doSearch() {
		const q = query.trim();
		if (!q) {
			results = [];
			pagination = null;
			searched = false;
			return;
		}
		loading = true;
		searched = true;
		try {
			const res = await searchEmails(q);
			results = res.emails;
			pagination = res.pagination;
		} finally {
			loading = false;
		}
	}

	async function loadMore() {
		if (!pagination?.has_more || !pagination.next_cursor) return;
		loading = true;
		const res = await searchEmails(query.trim(), { after: pagination.next_cursor });
		results = [...results, ...res.emails];
		pagination = res.pagination;
		loading = false;
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

<div class="p-8 max-w-4xl mx-auto overflow-auto h-full">
	<h2 class="text-2xl font-display font-bold text-text-primary mb-6">Search</h2>

	<div class="relative mb-6">
		<span
			class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-text-dim text-xl"
			>search</span
		>
		<input
			type="text"
			bind:value={query}
			oninput={handleInput}
			placeholder="Search emails across all projects..."
			class="w-full pl-12 pr-4 py-3 bg-surface border border-border rounded-lg font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
		/>
	</div>

	{#if loading && results.length === 0}
		<p class="text-text-dim font-mono text-sm">Searching...</p>
	{:else if searched && results.length === 0}
		<div class="text-center py-12">
			<span class="material-symbols-outlined text-4xl text-text-dim mb-3">search_off</span>
			<p class="text-text-secondary font-mono text-sm">No results found for "{query}"</p>
		</div>
	{:else if results.length > 0}
		<p class="text-xs font-mono text-text-dim mb-4">{pagination?.total_count ?? results.length} results</p>
		<div class="space-y-3">
			{#each results as result (result.id)}
				<a
					href="/projects/{result.inbox_id}/emails/{result.id}"
					class="block p-4 rounded-lg border border-border bg-surface hover:border-phosphor/30 hover:bg-surface-2 transition-all"
				>
					<p class="text-sm font-display font-medium text-text-primary">
						{result.subject || '(no subject)'}
					</p>
					<div class="flex items-center gap-2 mt-1 text-xs font-mono text-text-secondary">
						<span>{result.from}</span>
						<span class="text-text-dim">→</span>
						<span>{result.inbox_address}</span>
					</div>
					<div class="flex items-center gap-2 mt-1 text-xs font-mono text-text-dim">
						<span>{result.project_name}</span>
						<span>·</span>
						<span>{timeAgo(result.received_at)}</span>
					</div>
					{#if result.preview}
						<p class="text-xs text-text-secondary mt-2 line-clamp-2">{result.preview}</p>
					{/if}
				</a>
			{/each}
		</div>

		{#if pagination?.has_more}
			<div class="mt-4 text-center">
				<button
					onclick={loadMore}
					disabled={loading}
					class="px-4 py-2 text-sm font-mono text-phosphor hover:underline disabled:opacity-50"
				>
					{loading ? 'Loading...' : 'Load more'}
				</button>
			</div>
		{/if}
	{/if}
</div>
