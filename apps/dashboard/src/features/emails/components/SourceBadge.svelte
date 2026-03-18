<script lang="ts">
	let { sourceType }: { sourceType: string } = $props();

	const config = $derived.by(() => {
		switch (sourceType) {
			case 'inbound':
				return { color: 'bg-phosphor/15 text-phosphor', label: 'Inbound', dot: 'bg-phosphor' };
			case 'inbound_redacted':
				return { color: 'bg-amber/15 text-amber', label: 'Inbound (Limited)', dot: 'bg-amber' };
			default:
				return null;
		}
	});
</script>

{#if config}
	<span
		class="inline-flex items-center gap-1.5 px-1.5 py-0 rounded text-[9px] font-mono font-medium {config.color}"
	>
		<span class="size-1.5 rounded-full {config.dot}"></span>
		{config.label}
	</span>
{/if}
