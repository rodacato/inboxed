<script lang="ts">
	import StatusPanel from '../../features/system/StatusPanel.svelte';
	import type { ConnectionStatus } from '../../features/system/system.types';

	let { apiStatus = 'checking...' }: { apiStatus: ConnectionStatus } = $props();

	const navItems = [
		{ icon: 'inbox', label: 'Inbox', count: 4, active: true },
		{ icon: 'send', label: 'Sent', count: 0, active: false },
		{ icon: 'delete', label: 'Trash', count: 0, active: false },
	];
</script>

<aside class="w-64 flex flex-col border-r border-border bg-surface shrink-0">
	<div class="p-6">
		<div class="flex items-center gap-3 mb-8">
			<div class="size-8 bg-phosphor rounded-lg flex items-center justify-center text-base">
				<span class="material-symbols-outlined">alternate_email</span>
			</div>
			<h1 class="font-display font-bold text-xl tracking-tight text-text-primary">Inboxed</h1>
		</div>

		<nav class="space-y-1">
			{#each navItems as item (item.label)}
				<button
					class="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition-colors {item.active
						? 'bg-phosphor-glow text-phosphor font-medium'
						: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary'}"
				>
					<span class="material-symbols-outlined text-xl">{item.icon}</span>
					{item.label}
					{#if item.count > 0}
						<span class="ml-auto text-xs font-bold bg-phosphor text-base px-2 py-0.5 rounded-full"
							>{item.count}</span
						>
					{/if}
				</button>
			{/each}
		</nav>

		<div class="mt-10 pt-6 border-t border-border">
			<h3 class="px-4 text-[10px] font-bold uppercase tracking-widest text-text-dim mb-3 font-mono">
				Labels
			</h3>
			<div class="space-y-1">
				<button
					class="w-full flex items-center gap-3 px-4 py-2 text-sm text-text-secondary hover:text-phosphor"
				>
					<span class="size-2 rounded-full bg-amber"></span>
					OTP Codes
				</button>
				<button
					class="w-full flex items-center gap-3 px-4 py-2 text-sm text-text-secondary hover:text-phosphor"
				>
					<span class="size-2 rounded-full bg-cyan"></span>
					Notifications
				</button>
			</div>
		</div>
	</div>

	<div class="mt-auto p-6">
		<StatusPanel status={apiStatus} />
	</div>
</aside>
