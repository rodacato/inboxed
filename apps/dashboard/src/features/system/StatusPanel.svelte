<script lang="ts">
	import type { ConnectionStatus } from './system.types';

	let { status }: { status: ConnectionStatus } = $props();
</script>

<div class="flex items-center gap-3 p-3 rounded-lg bg-surface-2 border border-border">
	<div
		class="size-2 rounded-full {status === 'connected'
			? 'bg-phosphor'
			: status === 'error'
				? 'bg-error'
				: 'bg-amber animate-pulse'}"
	></div>
	<span class="text-xs font-mono text-text-secondary truncate">
		API: {status}
	</span>
</div>
