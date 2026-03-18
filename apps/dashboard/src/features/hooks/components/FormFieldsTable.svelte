<script lang="ts">
	let {
		body,
		contentType
	}: { body: string | null; contentType: string | null } = $props();

	const isFormData = $derived(
		contentType?.includes('application/x-www-form-urlencoded') ||
			contentType?.includes('multipart/form-data') ||
			false
	);

	const fields = $derived.by(() => {
		if (!body || !isFormData) return [];
		try {
			const params = new URLSearchParams(body);
			return Array.from(params.entries()).map(([key, value]) => ({ key, value }));
		} catch {
			return [];
		}
	});
</script>

{#if fields.length > 0}
	<div class="rounded-lg border border-border overflow-hidden">
		<table class="w-full text-sm">
			<thead class="bg-surface-2">
				<tr class="text-left text-xs font-mono text-text-dim uppercase">
					<th class="px-4 py-2">Field</th>
					<th class="px-4 py-2">Value</th>
				</tr>
			</thead>
			<tbody>
				{#each fields as { key, value } (key)}
					<tr class="border-t border-border hover:bg-surface-2/50">
						<td class="px-4 py-2 font-mono text-text-secondary whitespace-nowrap">{key}</td>
						<td class="px-4 py-2 font-mono text-text-primary break-all">{value}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{:else if body}
	<p class="text-sm font-mono text-text-dim">Unable to parse form fields</p>
{:else}
	<p class="text-sm font-mono text-text-dim">No form data</p>
{/if}
