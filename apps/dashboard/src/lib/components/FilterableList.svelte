<script lang="ts">
	import type { Snippet } from 'svelte';

	interface FilterChip {
		id: string;
		label: string;
		count?: number;
		active?: boolean;
	}

	interface Props {
		title: string;
		totalCount?: number;
		filters?: FilterChip[];
		activeFilter?: string | null;
		onFilterChange?: (filterId: string | null) => void;
		hasMore?: boolean;
		loadingMore?: boolean;
		onLoadMore?: () => void;
		loading?: boolean;
		headerActions?: Snippet;
		items: Snippet;
		emptyState?: Snippet;
	}

	let {
		title,
		totalCount,
		filters,
		activeFilter = null,
		onFilterChange,
		hasMore = false,
		loadingMore = false,
		onLoadMore,
		loading = false,
		headerActions,
		items,
		emptyState
	}: Props = $props();
</script>

<div class="flex flex-col h-full overflow-hidden">
	<!-- Header -->
	<div class="px-4 py-3 border-b border-border bg-surface shrink-0">
		<div class="flex items-center justify-between mb-1">
			<h2 class="text-sm font-display font-bold text-text-primary">{title}</h2>
			<div class="flex items-center gap-2">
				{#if totalCount !== undefined}
					<span class="text-[10px] font-mono text-text-dim">{totalCount} total</span>
				{/if}
				{#if headerActions}
					{@render headerActions()}
				{/if}
			</div>
		</div>

		<!-- Filter chips -->
		{#if filters && filters.length > 1}
			<div class="flex flex-wrap gap-1.5 mt-2">
				<button
					onclick={() => onFilterChange?.(null)}
					class="px-2 py-0.5 rounded text-[10px] font-mono transition-colors
						{activeFilter === null
						? 'bg-phosphor text-base font-medium'
						: 'bg-surface-2 text-text-secondary hover:text-text-primary'}"
				>
					All
				</button>
				{#each filters as chip (chip.id)}
					<button
						onclick={() => onFilterChange?.(chip.id)}
						class="px-2 py-0.5 rounded text-[10px] font-mono transition-colors
							{activeFilter === chip.id
							? 'bg-phosphor text-base font-medium'
							: 'bg-surface-2 text-text-secondary hover:text-text-primary'}"
					>
						{chip.label}
						{#if chip.count !== undefined}
							<span class="text-text-dim ml-0.5">({chip.count})</span>
						{/if}
					</button>
				{/each}
			</div>
		{/if}
	</div>

	<!-- List content -->
	<div class="flex-1 overflow-y-auto">
		{#if loading}
			<div class="flex items-center justify-center h-full">
				<p class="text-text-dim font-mono text-xs">Loading...</p>
			</div>
		{:else}
			{@render items()}
		{/if}

		<!-- Load more -->
		{#if hasMore}
			<div class="p-3 text-center border-t border-border">
				<button
					onclick={onLoadMore}
					disabled={loadingMore}
					class="text-xs font-mono text-phosphor hover:underline disabled:opacity-50"
				>
					{loadingMore ? 'Loading...' : 'Load more'}
				</button>
			</div>
		{/if}
	</div>
</div>
