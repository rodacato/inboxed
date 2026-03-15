<script lang="ts">
	import { page } from '$app/stores';
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { fetchEmails, purgeInbox } from '../../../../../features/emails/emails.service';
	import { deleteInbox } from '../../../../../features/inboxes/inboxes.service';
	import { getRealtimeStore } from '../../../../../features/realtime/realtime.store.svelte';
	import type { EmailSummary } from '../../../../../features/emails/emails.types';
	import type { Pagination } from '../../../../../features/projects/projects.types';

	const projectId = $derived($page.params.projectId);
	const inboxId = $derived($page.params.inboxId);
	const realtime = getRealtimeStore();

	let emails = $state<EmailSummary[]>([]);
	let pagination = $state<Pagination | null>(null);
	let loading = $state(true);
	let loadingMore = $state(false);
	let unsubscribe: (() => void) | undefined;
	let newEmailIds = $state(new Set<string>());

	onMount(async () => {
		const res = await fetchEmails(projectId, inboxId);
		emails = res.emails;
		pagination = res.pagination;
		loading = false;

		unsubscribe = realtime.subscribeToInbox(inboxId, (msg) => {
			if (msg.type === 'email_received') {
				const email = msg.email as EmailSummary;
				emails = [email, ...emails];
				newEmailIds = new Set([...newEmailIds, email.id]);
			} else if (msg.type === 'email_deleted') {
				emails = emails.filter((e) => e.id !== msg.email_id);
			} else if (msg.type === 'inbox_purged') {
				emails = [];
			}
		});
	});

	onDestroy(() => unsubscribe?.());

	async function loadMore() {
		if (!pagination?.has_more || !pagination.next_cursor) return;
		loadingMore = true;
		const res = await fetchEmails(projectId, inboxId, { after: pagination.next_cursor });
		emails = [...emails, ...res.emails];
		pagination = res.pagination;
		loadingMore = false;
	}

	async function handlePurge() {
		if (!confirm('Delete ALL emails in this inbox? This cannot be undone.')) return;
		await purgeInbox(projectId, inboxId);
		emails = [];
	}

	async function handleDeleteInbox() {
		if (!confirm('Delete this inbox and all its emails? This cannot be undone.')) return;
		await deleteInbox(projectId, inboxId);
		goto(`/projects/${projectId}`);
	}

	function timeAgo(iso: string): string {
		const diff = Date.now() - new Date(iso).getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 1) return 'just now';
		if (mins < 60) return `${mins}m ago`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h ago`;
		return `${Math.floor(hours / 24)}d ago`;
	}
</script>

<div class="p-8 max-w-5xl">
	<!-- Breadcrumb -->
	<div class="flex items-center gap-2 text-sm font-mono text-text-secondary mb-6">
		<a href="/projects" class="hover:text-phosphor">Projects</a>
		<span class="text-text-dim">/</span>
		<a href="/projects/{projectId}" class="hover:text-phosphor">Project</a>
		<span class="text-text-dim">/</span>
		<span class="text-text-primary">Inbox</span>
	</div>

	<div class="flex items-center justify-between mb-6">
		<div>
			<h2 class="text-xl font-display font-bold text-text-primary">Emails</h2>
			{#if pagination}
				<p class="text-xs font-mono text-text-dim mt-1">{pagination.total_count} emails</p>
			{/if}
		</div>
		<div class="flex gap-2">
			<button
				onclick={handlePurge}
				class="px-3 py-1.5 text-xs font-mono text-warning border border-warning/30 rounded hover:bg-warning/10 transition-colors"
			>
				Purge All
			</button>
			<button
				onclick={handleDeleteInbox}
				class="px-3 py-1.5 text-xs font-mono text-error border border-error/30 rounded hover:bg-error/10 transition-colors"
			>
				Delete Inbox
			</button>
		</div>
	</div>

	{#if loading}
		<p class="text-text-dim font-mono text-sm">Loading emails...</p>
	{:else if emails.length === 0}
		<div class="text-center py-20">
			<span class="material-symbols-outlined text-5xl text-text-dim mb-4">mail</span>
			<p class="text-text-secondary font-mono">No emails yet. Waiting for incoming mail...</p>
		</div>
	{:else}
		<div class="rounded-lg border border-border overflow-hidden divide-y divide-border">
			{#each emails as email (email.id)}
				<a
					href="/projects/{projectId}/emails/{email.id}"
					class="block px-5 py-4 hover:bg-surface-2/50 transition-colors"
				>
					<div class="flex items-start justify-between gap-4">
						<div class="min-w-0 flex-1">
							<div class="flex items-center gap-2">
								{#if newEmailIds.has(email.id)}
									<span class="size-2 rounded-full bg-phosphor shrink-0"></span>
								{/if}
								<span class="text-sm font-mono text-text-primary truncate">{email.from}</span>
								<span class="text-xs font-mono text-text-dim shrink-0"
									>{timeAgo(email.received_at)}</span
								>
							</div>
							<p class="text-sm text-text-primary mt-1 truncate">{email.subject || '(no subject)'}</p>
							<p class="text-xs text-text-secondary mt-0.5 truncate">{email.preview}</p>
						</div>
						<div class="flex items-center gap-2 shrink-0">
							{#if email.has_attachments}
								<span class="material-symbols-outlined text-base text-text-dim">attach_file</span>
							{/if}
						</div>
					</div>
				</a>
			{/each}
		</div>

		{#if pagination?.has_more}
			<div class="mt-4 text-center">
				<button
					onclick={loadMore}
					disabled={loadingMore}
					class="px-4 py-2 text-sm font-mono text-phosphor hover:underline disabled:opacity-50"
				>
					{loadingMore ? 'Loading...' : 'Load more'}
				</button>
			</div>
		{/if}
	{/if}
</div>
