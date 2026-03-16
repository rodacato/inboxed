<script lang="ts">
	let {
		body,
		contentType
	}: { body: string | null; contentType: string | null } = $props();

	let viewMode = $state<'pretty' | 'raw'>('pretty');
	let copied = $state(false);

	const isJson = $derived(contentType?.includes('json') ?? false);

	const prettyBody = $derived.by(() => {
		if (!body || !isJson) return body ?? '';
		try {
			return JSON.stringify(JSON.parse(body), null, 2);
		} catch {
			return body;
		}
	});

	const displayBody = $derived(viewMode === 'pretty' && isJson ? prettyBody : (body ?? ''));

	function copyBody() {
		if (body) {
			navigator.clipboard.writeText(body);
			copied = true;
			setTimeout(() => (copied = false), 2000);
		}
	}
</script>

<div>
	<div class="flex items-center gap-2 mb-2">
		{#if isJson}
			<div class="flex rounded border border-border overflow-hidden">
				<button
					onclick={() => (viewMode = 'pretty')}
					class="px-2 py-0.5 text-xs font-mono transition-colors
						{viewMode === 'pretty'
						? 'bg-phosphor text-base'
						: 'text-text-secondary hover:bg-surface-2'}"
				>
					Pretty
				</button>
				<button
					onclick={() => (viewMode = 'raw')}
					class="px-2 py-0.5 text-xs font-mono transition-colors
						{viewMode === 'raw'
						? 'bg-phosphor text-base'
						: 'text-text-secondary hover:bg-surface-2'}"
				>
					Raw
				</button>
			</div>
		{/if}
		<div class="flex-1"></div>
		{#if body}
			<button
				onclick={copyBody}
				class="px-2 py-0.5 text-xs font-mono text-text-secondary hover:text-text-primary border border-border rounded"
			>
				{copied ? 'Copied!' : 'Copy'}
			</button>
		{/if}
	</div>

	{#if body}
		<pre
			class="p-4 rounded-lg bg-surface-2 border border-border text-sm font-mono text-text-primary overflow-auto max-h-96 whitespace-pre-wrap break-all"
		>{displayBody}</pre>
	{:else}
		<p class="text-sm font-mono text-text-dim">No body</p>
	{/if}
</div>
