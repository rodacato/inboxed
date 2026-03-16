<script lang="ts">
	let { headers }: { headers: Record<string, string> } = $props();

	const entries = $derived(Object.entries(headers).sort(([a], [b]) => a.localeCompare(b)));
</script>

{#if entries.length > 0}
	<div class="rounded-lg border border-border overflow-hidden">
		<table class="w-full text-sm">
			<thead class="bg-surface-2">
				<tr class="text-left text-xs font-mono text-text-dim uppercase">
					<th class="px-4 py-2">Header</th>
					<th class="px-4 py-2">Value</th>
				</tr>
			</thead>
			<tbody>
				{#each entries as [key, value] (key)}
					<tr class="border-t border-border hover:bg-surface-2/50">
						<td class="px-4 py-2 font-mono text-text-secondary whitespace-nowrap">{key}</td>
						<td class="px-4 py-2 font-mono text-text-primary break-all">{value}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{:else}
	<p class="text-sm font-mono text-text-dim">No headers</p>
{/if}
