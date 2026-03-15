<script lang="ts">
	import type { Message } from './messages.types';

	let {
		messages,
		selectedId,
		onSelect
	}: {
		messages: Message[];
		selectedId: string;
		onSelect: (id: string) => void;
	} = $props();
</script>

<main class="w-[380px] flex flex-col border-r border-border bg-base overflow-hidden shrink-0">
	<div class="p-5 border-b border-border">
		<h2 class="font-mono text-sm font-bold text-phosphor mb-3 truncate">
			signup@mail.inboxed.dev
		</h2>
		<div class="relative">
			<span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-text-dim text-lg"
				>search</span
			>
			<input
				class="w-full bg-surface border border-border rounded-lg py-2 pl-9 pr-4 text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor/40 font-mono"
				placeholder="search..."
				type="text"
			/>
		</div>
	</div>

	<div class="flex-1 overflow-y-auto">
		{#each messages as email}
			<button
				class="w-full text-left p-4 border-b border-border/50 cursor-pointer transition-colors
					{selectedId === email.id
					? 'bg-phosphor-glow border-l-2 border-l-phosphor'
					: 'hover:bg-surface-2 border-l-2 border-l-transparent'}"
				onclick={() => onSelect(email.id)}
			>
				<div class="flex justify-between items-start mb-1">
					<span class="font-mono text-[11px] text-text-dim">{email.fromDomain}</span>
					<div class="flex items-center gap-2">
						{#if email.isNew}
							<span
								class="text-[10px] font-bold bg-amber/20 text-amber border border-amber/30 px-1.5 py-0.5 rounded font-mono uppercase"
								>New</span
							>
						{/if}
						<span class="text-[10px] font-mono text-text-dim">{email.time}</span>
					</div>
				</div>
				<h4 class="text-sm mb-1 {email.isNew ? 'font-semibold text-text-primary' : 'font-normal text-text-secondary'}">
					{email.subject}
				</h4>
				<p class="text-xs text-text-dim line-clamp-2">{email.preview}</p>
			</button>
		{/each}
	</div>
</main>
