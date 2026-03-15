<script lang="ts">
	import '../app.css';
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { isAuthenticated } from '$lib/api-client';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import { getRealtimeStore } from '../features/realtime/realtime.store.svelte';

	let { children } = $props();
	let ready = $state(false);
	const realtime = getRealtimeStore();

	onMount(() => {
		if (!isAuthenticated() && $page.url.pathname !== '/login') {
			goto('/login');
			return;
		}
		if (isAuthenticated()) {
			realtime.connect();
		}
		ready = true;
	});

	const isLogin = $derived($page.url.pathname === '/login');
</script>

{#if isLogin}
	{@render children()}
{:else if ready}
	<div class="flex h-screen overflow-hidden bg-base">
		<Sidebar wsConnected={realtime.connected} />
		<main class="flex-1 overflow-hidden">
			{@render children()}
		</main>
	</div>
{/if}
