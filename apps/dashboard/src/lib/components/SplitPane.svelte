<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		listWidth?: string;
		showDetail?: boolean;
		list: Snippet;
		detail: Snippet;
		empty?: Snippet;
	}

	let { listWidth = 'w-96', showDetail = false, list, detail, empty }: Props = $props();

	let mobileShowDetail = $derived(showDetail);
</script>

<div class="flex h-full overflow-hidden">
	<!-- Left panel: list -->
	<div
		class="{listWidth} shrink-0 flex flex-col border-r border-border bg-base overflow-hidden
			max-md:{mobileShowDetail ? 'hidden' : 'w-full'}"
	>
		{@render list()}
	</div>

	<!-- Right panel: detail or empty state -->
	<div
		class="flex-1 overflow-hidden bg-base
			max-md:{!mobileShowDetail ? 'hidden' : 'w-full'}"
	>
		{#if showDetail}
			{@render detail()}
		{:else if empty}
			{@render empty()}
		{:else}
			<div class="flex flex-col items-center justify-center h-full text-text-dim">
				<span class="material-symbols-outlined text-6xl mb-4">mark_email_read</span>
				<p class="font-mono text-sm">Select an item to inspect</p>
			</div>
		{/if}
	</div>
</div>
