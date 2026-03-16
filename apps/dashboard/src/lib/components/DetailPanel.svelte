<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Tab {
		id: string;
		label: string;
		badge?: string;
	}

	interface Props {
		title: string;
		tabs: Tab[];
		activeTab?: string;
		onTabChange?: (tabId: string) => void;
		onBack?: () => void;
		banner?: Snippet;
		metadata: Snippet;
		content: Snippet;
		actions?: Snippet;
		footer?: Snippet;
	}

	let {
		title,
		tabs,
		activeTab = tabs[0]?.id,
		onTabChange,
		onBack,
		banner,
		metadata,
		content,
		actions,
		footer
	}: Props = $props();
</script>

<div class="flex flex-col h-full overflow-hidden">
	<!-- Banner (OTP, status, etc.) -->
	{#if banner}
		{@render banner()}
	{/if}

	<!-- Header + Metadata -->
	<div class="px-6 pt-4 pb-3 shrink-0 border-b border-border">
		<div class="flex items-start justify-between mb-3">
			<div class="flex items-center gap-3 min-w-0 pr-4">
				{#if onBack}
					<button
						onclick={onBack}
						class="md:hidden shrink-0 text-text-secondary hover:text-text-primary transition-colors"
					>
						<span class="material-symbols-outlined text-xl">arrow_back</span>
					</button>
				{/if}
				<h2 class="text-lg font-display font-bold text-text-primary leading-tight truncate">
					{title}
				</h2>
			</div>
			{#if actions}
				<div class="flex items-center gap-2 shrink-0">
					{@render actions()}
				</div>
			{/if}
		</div>

		<!-- Metadata -->
		{@render metadata()}
	</div>

	<!-- Tabs -->
	<div class="flex border-b border-border shrink-0 px-6 gap-0 bg-surface overflow-x-auto">
		{#each tabs as tab (tab.id)}
			<button
				onclick={() => onTabChange?.(tab.id)}
				class="px-4 py-2.5 text-xs font-mono uppercase tracking-wide transition-colors border-b-2 -mb-px whitespace-nowrap
					{activeTab === tab.id
					? 'border-phosphor text-phosphor'
					: 'border-transparent text-text-secondary hover:text-text-primary'}"
			>
				{tab.label}
				{#if tab.badge}
					<span class="ml-1 text-[9px] px-1 py-0.5 rounded bg-surface-2 text-text-dim">{tab.badge}</span>
				{/if}
			</button>
		{/each}
	</div>

	<!-- Tab Content -->
	<div class="flex-1 overflow-auto bg-surface">
		{@render content()}
	</div>

	<!-- Footer (attachments, expiry, etc.) -->
	{#if footer}
		{@render footer()}
	{/if}
</div>
