<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';

	// Redirect old /projects/[id] to /projects/[id]/settings
	$effect(() => {
		const pid = $page.params.projectId;
		goto(`/projects/${pid}/settings`, { replaceState: true });
	});
</script>
