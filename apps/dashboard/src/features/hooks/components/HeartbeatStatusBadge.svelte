<script lang="ts">
	let { status }: { status: string | null } = $props();

	const config = $derived.by(() => {
		switch (status) {
			case 'healthy':
				return { color: 'bg-phosphor/15 text-phosphor', label: 'healthy', dot: 'bg-phosphor' };
			case 'late':
				return { color: 'bg-amber/15 text-amber', label: 'late', dot: 'bg-amber' };
			case 'down':
				return { color: 'bg-error/15 text-error', label: 'down', dot: 'bg-error' };
			case 'pending':
				return {
					color: 'bg-text-dim/15 text-text-dim',
					label: 'pending',
					dot: 'bg-text-dim'
				};
			default:
				return { color: 'bg-text-dim/15 text-text-dim', label: '—', dot: 'bg-text-dim' };
		}
	});
</script>

<span
	class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-xs font-mono font-medium {config.color}"
>
	<span class="size-1.5 rounded-full {config.dot}"></span>
	{config.label}
</span>
