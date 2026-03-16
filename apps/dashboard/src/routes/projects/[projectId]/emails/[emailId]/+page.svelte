<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';

	// Redirect old /projects/[id]/emails/[eid] to /projects/[id]/mail/[eid]
	$effect(() => {
		const pid = $page.params.projectId;
		const eid = $page.params.emailId;
		goto(`/projects/${pid}/mail/${eid}`, { replaceState: true });
	});
</script>
