<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';

	// Redirect old /projects/[id]/emails to /projects/[id]/mail
	$effect(() => {
		const pid = $page.params.projectId;
		goto(`/projects/${pid}/mail`, { replaceState: true });
	});
</script>
