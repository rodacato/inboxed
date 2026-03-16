<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		icon: string;
		title: string;
		description?: string;
		content?: Snippet;
		action?: Snippet;
	}

	let { icon, title, description, content, action }: Props = $props();
</script>

<div class="flex flex-col items-center justify-center py-16 px-8 text-center">
	<span class="material-symbols-outlined text-5xl text-text-dim mb-4">{icon}</span>
	<h3 class="font-display text-xl text-text-primary mb-2">{title}</h3>
	{#if description}
		<p class="text-text-secondary text-sm max-w-md mb-6">{description}</p>
	{/if}
	{#if content}
		{@render content()}
	{/if}
	{#if action}
		<div class="mt-6">
			{@render action()}
		</div>
	{/if}
</div>
