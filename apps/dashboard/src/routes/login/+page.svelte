<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import LoginForm from '../../features/auth/LoginForm.svelte';
	import { toastStore } from '$lib/stores/toast.store.svelte';

	onMount(() => {
		const reason = $page.url.searchParams.get('reason');
		if (reason === 'session_expired') {
			toastStore.add({
				type: 'warning',
				title: 'Session expired',
				description: 'Please sign in again to continue.'
			});
			// Clean up the URL
			const url = new URL(window.location.href);
			url.searchParams.delete('reason');
			window.history.replaceState({}, '', url.pathname);
		}
	});
</script>

<LoginForm />
