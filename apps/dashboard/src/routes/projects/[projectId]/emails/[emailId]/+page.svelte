<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import EmailPreview from '$lib/components/EmailPreview.svelte';

	const projectId = $derived($page.params.projectId ?? '');
	const emailId = $derived($page.params.emailId ?? '');

	// We need inboxId for the preview component; we'll get it from the email detail
	// For now, pass projectId — the EmailPreview handles its own data fetching
	function handleDeleted() {
		goto(`/projects/${projectId}`);
	}
</script>

<div class="h-full overflow-hidden">
	<EmailPreview
		{emailId}
		{projectId}
		inboxId=""
		onDeleted={handleDeleted}
	/>
</div>
