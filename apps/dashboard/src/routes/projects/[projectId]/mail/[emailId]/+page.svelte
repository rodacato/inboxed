<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import EmailPreview from '$lib/components/EmailPreview.svelte';

	const projectId = $derived($page.params.projectId ?? '');
	const emailId = $derived($page.params.emailId ?? '');

	function handleDeleted() {
		goto(`/projects/${projectId}/mail`);
	}
</script>

<div class="h-full overflow-auto">
	<div class="px-4 py-2 border-b border-border bg-surface shrink-0">
		<a
			href="/projects/{projectId}/mail"
			class="inline-flex items-center gap-1 text-xs font-mono text-text-secondary hover:text-phosphor transition-colors"
		>
			<span class="material-symbols-outlined text-base">arrow_back</span>
			Back to emails
		</a>
	</div>
	<EmailPreview {emailId} {projectId} inboxId="" onDeleted={handleDeleted} />
</div>
