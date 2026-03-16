<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';

	// Redirect old /projects/[id]/inboxes/[iid] to /projects/[id]/mail/inbox/[iid]
	$effect(() => {
		const pid = $page.params.projectId;
		const iid = $page.params.inboxId;
		goto(`/projects/${pid}/mail/inbox/${iid}`, { replaceState: true });
	});
</script>
