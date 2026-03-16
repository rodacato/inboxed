<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { authStore } from '$lib/stores/auth.store.svelte';
	import LandingPage from '$lib/components/LandingPage.svelte';

	let showLanding = $state(false);

	onMount(async () => {
		await authStore.loadStatus();

		if (authStore.isAuthenticated) {
			goto('/projects');
			return;
		}

		showLanding = true;
	});
</script>

<svelte:head>
	<title>Inboxed — The dev inbox. Catch emails, webhooks, forms. Inspect everything.</title>
	<meta name="description" content="Self-hosted SMTP server for developers and QA. Catch test emails, inspect via API and dashboard, extract OTPs with AI agents via MCP. Open source." />
</svelte:head>

{#if showLanding}
	<LandingPage />
{/if}
