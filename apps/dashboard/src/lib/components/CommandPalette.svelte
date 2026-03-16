<script lang="ts">
	import { commandStore, type Command } from '$lib/stores/commands.store.svelte';
	import { SvelteMap } from 'svelte/reactivity';

	let query = $state('');
	let selectedIndex = $state(0);
	let inputEl = $state<HTMLInputElement | null>(null);

	const filtered = $derived(commandStore.search(query));

	const grouped = $derived.by(() => {
		const groups = new SvelteMap<string, Command[]>();
		for (const cmd of filtered) {
			const list = groups.get(cmd.category) ?? [];
			list.push(cmd);
			groups.set(cmd.category, list);
		}
		return groups;
	});

	const flatList = $derived(filtered);

	$effect(() => {
		if (commandStore.isOpen) {
			query = '';
			selectedIndex = 0;
			// Focus input after mount
			requestAnimationFrame(() => inputEl?.focus());
		}
	});

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'ArrowDown') {
			e.preventDefault();
			selectedIndex = Math.min(selectedIndex + 1, flatList.length - 1);
		} else if (e.key === 'ArrowUp') {
			e.preventDefault();
			selectedIndex = Math.max(selectedIndex - 1, 0);
		} else if (e.key === 'Enter') {
			e.preventDefault();
			const cmd = flatList[selectedIndex];
			if (cmd) {
				commandStore.hide();
				cmd.execute();
			}
		} else if (e.key === 'Escape') {
			commandStore.hide();
		}
	}

	function execute(cmd: Command) {
		commandStore.hide();
		cmd.execute();
	}

	const categoryLabels: Record<string, string> = {
		navigation: 'Navigation',
		action: 'Actions',
		recent: 'Recent'
	};
</script>

{#if commandStore.isOpen}
	<!-- Backdrop -->
	<div class="fixed inset-0 z-60 bg-black/50" role="presentation" onclick={() => commandStore.hide()}></div>

	<!-- Palette -->
	<div
		class="fixed inset-x-0 top-[20%] z-61 mx-auto w-full max-w-lg"
		role="dialog"
		aria-label="Command palette"
		tabindex="-1"
		onkeydown={handleKeydown}
	>
		<div class="bg-surface border border-border rounded-xl shadow-2xl overflow-hidden">
			<!-- Search input -->
			<div class="flex items-center gap-3 px-4 border-b border-border">
				<span class="material-symbols-outlined text-text-dim text-lg">search</span>
				<input
					bind:this={inputEl}
					bind:value={query}
					type="text"
					placeholder="Type a command or search..."
					class="flex-1 py-3.5 bg-transparent font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none"
				/>
				<kbd class="text-[10px] font-mono text-text-dim bg-surface-2 rounded px-1.5 py-0.5 border border-border">
					ESC
				</kbd>
			</div>

			<!-- Results -->
			<div class="max-h-80 overflow-y-auto py-2">
				{#if flatList.length === 0}
					<p class="px-4 py-6 text-center text-text-dim font-mono text-sm">No commands found</p>
				{:else}
					{#each [...grouped] as [category, cmds] (category)}
						<div class="px-3 pt-2 pb-1">
							<p class="text-[10px] font-mono font-bold uppercase tracking-widest text-text-dim px-1">
								{categoryLabels[category] ?? category}
							</p>
						</div>
						{#each cmds as cmd (cmd.id)}
							{@const globalIndex = flatList.indexOf(cmd)}
							<button
								onclick={() => execute(cmd)}
								class="w-full flex items-center gap-3 px-4 py-2 text-left transition-colors
									{globalIndex === selectedIndex
									? 'bg-phosphor-glow text-phosphor'
									: 'text-text-secondary hover:bg-surface-2'}"
							>
								{#if cmd.icon}
									<span class="material-symbols-outlined text-lg">{cmd.icon}</span>
								{/if}
								<span class="text-sm font-mono truncate">{cmd.label}</span>
							</button>
						{/each}
					{/each}
				{/if}
			</div>
		</div>
	</div>
{/if}
