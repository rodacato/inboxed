<script lang="ts">
	import { toastStore } from '$lib/stores/toast.store.svelte';

	const iconMap: Record<string, string> = {
		info: 'info',
		success: 'check_circle',
		warning: 'warning',
		error: 'error'
	};

	const colorMap: Record<string, string> = {
		info: 'text-cyan',
		success: 'text-phosphor',
		warning: 'text-amber',
		error: 'text-error'
	};
</script>

<div class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm pointer-events-none">
	{#each toastStore.items as toast (toast.id)}
		<div
			class="pointer-events-auto bg-surface border border-border rounded-lg p-3 shadow-lg flex items-start gap-3 animate-slide-in"
			role="alert"
		>
			<span class="material-symbols-outlined {colorMap[toast.type]} text-lg shrink-0 mt-0.5">
				{iconMap[toast.type]}
			</span>
			<div class="flex-1 min-w-0">
				<p class="font-mono text-sm text-text-primary">{toast.title}</p>
				{#if toast.description}
					<p class="text-xs text-text-secondary mt-0.5 truncate">{toast.description}</p>
				{/if}
				{#if toast.action}
					<a
						href={toast.action.href}
						class="text-xs text-phosphor hover:underline mt-1 inline-block"
					>
						{toast.action.label} &rarr;
					</a>
				{/if}
			</div>
			<button
				onclick={() => toastStore.dismiss(toast.id)}
				class="text-text-dim hover:text-text-secondary shrink-0"
			>
				<span class="material-symbols-outlined text-base">close</span>
			</button>
		</div>
	{/each}
</div>

<style>
	@keyframes slide-in {
		from {
			transform: translateX(100%);
			opacity: 0;
		}
		to {
			transform: translateX(0);
			opacity: 1;
		}
	}
	.animate-slide-in {
		animation: slide-in 0.2s ease-out;
	}
</style>
