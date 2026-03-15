<script lang="ts">
	import { onMount } from 'svelte';
	import { isAuthenticated } from '$lib/api-client';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import MessageList from '../features/messages/MessageList.svelte';
	import MessagePreview from '../features/messages/MessagePreview.svelte';
	import { getMessagesStore } from '../features/messages/messages.store';
	import { checkApiStatus } from '../features/system/system.service';
	import type { ConnectionStatus } from '../features/system/system.types';

	const store = getMessagesStore();
	let apiStatus = $state<ConnectionStatus>('checking...');

	onMount(async () => {
		if (!isAuthenticated()) {
			window.location.href = '/login';
			return;
		}
		apiStatus = await checkApiStatus();
	});
</script>

<div class="flex h-screen overflow-hidden bg-base">
	<Sidebar {apiStatus} />
	<MessageList
		messages={store.messages}
		selectedId={store.selectedId}
		onSelect={(id) => store.select(id)}
	/>
	<MessagePreview />
</div>
