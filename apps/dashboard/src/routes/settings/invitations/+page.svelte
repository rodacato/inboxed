<script lang="ts">
	// Redirect to members page which includes invitations
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';

	onMount(() => {
		goto('/settings/members', { replaceState: true });
	});
</script>

<div class="h-full flex items-center justify-center">
	<p class="text-text-dim font-mono text-sm">Redirecting...</p>
</div>
