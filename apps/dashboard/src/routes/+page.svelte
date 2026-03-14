<script lang="ts">
	import { onMount } from 'svelte';
	import { isAuthenticated, apiClient } from '$lib/api';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import EmailList from '$lib/components/EmailList.svelte';
	import EmailPreview from '$lib/components/EmailPreview.svelte';

	let apiStatus = $state<string>('checking...');

	onMount(async () => {
		if (!isAuthenticated()) {
			window.location.href = '/login';
			return;
		}
		try {
			const res = await apiClient('/admin/status') as { status: string };
			apiStatus = res.status === 'ok' ? 'connected' : 'error';
		} catch {
			apiStatus = 'disconnected';
		}
	});
</script>

<div class="flex h-screen overflow-hidden bg-base">
	<Sidebar {apiStatus} />
	<EmailList />
	<EmailPreview />
</div>
