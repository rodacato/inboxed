<script lang="ts">
	import type { HttpRequestSummary } from '../hooks.types';

	let {
		requests
	}: { requests: HttpRequestSummary[] } = $props();

	const HOURS = 24;
	const SLOTS = 48; // half-hour slots
	const slotDuration = (HOURS * 60 * 60 * 1000) / SLOTS;

	const now = $derived(Date.now());
	const timelineStart = $derived(now - HOURS * 60 * 60 * 1000);

	const slots = $derived.by(() => {
		const result: { start: number; end: number; count: number; missed: boolean }[] = [];

		for (let i = 0; i < SLOTS; i++) {
			const slotStart = timelineStart + i * slotDuration;
			const slotEnd = slotStart + slotDuration;
			const count = requests.filter((r) => {
				const t = new Date(r.received_at).getTime();
				return t >= slotStart && t < slotEnd;
			}).length;

			const missed = count === 0 && slotEnd < now;
			result.push({ start: slotStart, end: slotEnd, count, missed });
		}

		return result;
	});

	function formatTime(ts: number): string {
		return new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
	}

	const tickCount = 7;
	const tickInterval = (HOURS * 60 * 60 * 1000) / (tickCount - 1);
	const tickIndices = Array.from({ length: tickCount }, (__, i) => i);
</script>

<div class="space-y-2">
	<div class="flex items-center gap-1 h-8">
		{#each slots as slot, i (i)}
			<div
				class="flex-1 h-full rounded-sm transition-colors {slot.count > 0
					? 'bg-phosphor'
					: slot.missed
						? 'bg-danger/40'
						: 'bg-surface-2'}"
				title="{formatTime(slot.start)} — {slot.count} ping{slot.count !== 1 ? 's' : ''}"
			></div>
		{/each}
	</div>

	<div class="flex justify-between text-xs font-mono text-text-dim">
		{#each tickIndices as i (i)}
			<span>{formatTime(timelineStart + i * tickInterval)}</span>
		{/each}
	</div>

	<div class="flex items-center gap-4 text-xs font-mono text-text-dim mt-1">
		<span class="flex items-center gap-1">
			<span class="w-3 h-3 rounded-sm bg-phosphor inline-block"></span>
			Pings received
		</span>
		<span class="flex items-center gap-1">
			<span class="w-3 h-3 rounded-sm bg-danger/40 inline-block"></span>
			Missed
		</span>
		<span class="flex items-center gap-1">
			<span class="w-3 h-3 rounded-sm bg-surface-2 inline-block"></span>
			No data
		</span>
	</div>
</div>
