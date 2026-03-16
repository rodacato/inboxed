<script lang="ts">
	import '../app.css';
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { authStore } from '$lib/stores/auth.store.svelte';
	import { commandStore } from '$lib/stores/commands.store.svelte';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import ToastContainer from '$lib/components/ToastContainer.svelte';
	import CommandPalette from '$lib/components/CommandPalette.svelte';
	import { getRealtimeStore } from '../features/realtime/realtime.store.svelte';

	let { children } = $props();
	let ready = $state(false);
	let sidebarOpen = $state(false);
	let sidebarCollapsed = $state(false);
	const realtime = getRealtimeStore();

	onMount(() => {
		if (!authStore.isAuthenticated && $page.url.pathname !== '/login') {
			goto('/login');
			return;
		}
		if (authStore.isAuthenticated) {
			realtime.connect();
			authStore.loadStatus();
		}

		// Restore sidebar collapsed state
		sidebarCollapsed = localStorage.getItem('inboxed_sidebar_collapsed') === 'true';

		ready = true;
	});

	function handleKeydown(e: KeyboardEvent) {
		if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
			e.preventDefault();
			commandStore.toggle();
		}
	}

	function toggleSidebarCollapse() {
		sidebarCollapsed = !sidebarCollapsed;
		localStorage.setItem('inboxed_sidebar_collapsed', String(sidebarCollapsed));
	}

	function closeMobileSidebar() {
		sidebarOpen = false;
	}

	const isLogin = $derived($page.url.pathname === '/login');
</script>

<svelte:window onkeydown={handleKeydown} />

{#if isLogin}
	{@render children()}
{:else if ready}
	<div class="flex h-screen overflow-hidden bg-base">
		<!-- Desktop sidebar -->
		<div class="hidden md:block">
			<Sidebar wsConnected={realtime.connected} collapsed={sidebarCollapsed} />
		</div>

		<!-- Mobile sidebar drawer -->
		{#if sidebarOpen}
			<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
		<div class="fixed inset-0 z-40 bg-black/50 md:hidden" role="presentation" onclick={closeMobileSidebar}></div>
			<div class="fixed inset-y-0 left-0 z-50 md:hidden">
				<Sidebar wsConnected={realtime.connected} onNavigate={closeMobileSidebar} />
			</div>
		{/if}

		<!-- Main content -->
		<div class="flex-1 flex flex-col overflow-hidden">
			<!-- Mobile top bar -->
			<div class="flex md:hidden items-center gap-3 px-4 py-2 border-b border-border bg-surface shrink-0">
				<button
					onclick={() => (sidebarOpen = true)}
					class="text-text-secondary hover:text-text-primary"
				>
					<span class="material-symbols-outlined text-xl">menu</span>
				</button>
				<a href="/projects" class="flex items-center gap-2">
					<div class="size-6 bg-phosphor rounded flex items-center justify-center">
						<span class="material-symbols-outlined text-sm">alternate_email</span>
					</div>
					<span class="font-display font-bold text-sm text-text-primary">Inboxed</span>
				</a>
				<div class="flex-1"></div>
				<button
					onclick={() => commandStore.show()}
					class="text-text-secondary hover:text-text-primary"
				>
					<span class="material-symbols-outlined text-xl">search</span>
				</button>
			</div>

			<!-- Desktop sidebar collapse toggle -->
			<button
				onclick={toggleSidebarCollapse}
				class="hidden md:flex absolute left-0 top-1/2 -translate-y-1/2 z-10
					{sidebarCollapsed ? 'ml-13' : 'ml-59'}
					size-5 items-center justify-center rounded-full bg-surface-2 border border-border
					text-text-dim hover:text-text-primary transition-all opacity-0 hover:opacity-100"
				style="transition: margin-left 0.2s, opacity 0.2s;"
				title={sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
			>
				<span class="material-symbols-outlined text-xs">
					{sidebarCollapsed ? 'chevron_right' : 'chevron_left'}
				</span>
			</button>

			<main class="flex-1 overflow-hidden">
				{@render children()}
			</main>
		</div>
	</div>

	<ToastContainer />
	<CommandPalette />
{/if}
