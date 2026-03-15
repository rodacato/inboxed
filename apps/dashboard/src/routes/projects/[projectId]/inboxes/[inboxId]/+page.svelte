<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { fetchEmails, purgeInbox } from '../../../../../features/emails/emails.service';
	import { deleteInbox } from '../../../../../features/inboxes/inboxes.service';
	import { getRealtimeStore } from '../../../../../features/realtime/realtime.store.svelte';
	import type { EmailSummary } from '../../../../../features/emails/emails.types';
	import type { Pagination } from '../../../../../features/projects/projects.types';
	import EmailPreview from '$lib/components/EmailPreview.svelte';

	const projectId = $derived($page.params.projectId ?? '');
	const inboxId = $derived($page.params.inboxId ?? '');
	const realtime = getRealtimeStore();

	let emails = $state<EmailSummary[]>([]);
	let pagination = $state<Pagination | null>(null);
	let loading = $state(true);
	let loadingMore = $state(false);
	let unsubscribeFn: (() => void) | undefined;
	let newEmailIds = $state(new Set<string>());
	let selectedEmailId = $state<string | null>(null);

	// React to inboxId changes
	$effect(() => {
		const pid = projectId;
		const iid = inboxId;
		if (!pid || !iid) return;

		// Reset
		emails = [];
		pagination = null;
		loading = true;
		selectedEmailId = null;
		newEmailIds = new Set();
		unsubscribeFn?.();
		unsubscribeFn = undefined;

		loadInbox(pid, iid);
	});

	async function loadInbox(pid: string, iid: string) {
		const res = await fetchEmails(pid, iid);
		if (pid !== projectId || iid !== inboxId) return;

		emails = res.emails;
		pagination = res.pagination;
		loading = false;

		if (emails.length > 0) {
			selectedEmailId = emails[0].id;
		}

		unsubscribeFn = realtime.subscribeToInbox(iid, (msg) => {
			if (msg.type === 'email_received') {
				const email = msg.email as EmailSummary;
				emails = [email, ...emails];
				newEmailIds = new Set([...newEmailIds, email.id]);
				selectedEmailId = email.id;
			} else if (msg.type === 'email_deleted') {
				const wasSelected = selectedEmailId === msg.email_id;
				emails = emails.filter((e) => e.id !== msg.email_id);
				if (wasSelected) {
					selectedEmailId = emails.length > 0 ? emails[0].id : null;
				}
			} else if (msg.type === 'inbox_purged') {
				emails = [];
				selectedEmailId = null;
			}
		});
	}

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
		selectedEmailId = null;
	}

	async function handleDeleteInbox() {
		if (!confirm('Delete this inbox and all its emails? This cannot be undone.')) return;
		await deleteInbox(projectId, inboxId);
		goto(`/projects/${projectId}/emails`);
	}

	function selectEmail(id: string) {
		selectedEmailId = id;
		if (newEmailIds.has(id)) {
			const next = new Set(newEmailIds);
			next.delete(id);
			newEmailIds = next;
		}
	}

	function handleEmailDeleted() {
		emails = emails.filter((e) => e.id !== selectedEmailId);
		selectedEmailId = emails.length > 0 ? emails[0].id : null;
	}

	function timeAgo(iso: string): string {
		const diff = Date.now() - new Date(iso).getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 1) return 'now';
		if (mins < 60) return `${mins}m`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}h`;
		return `${Math.floor(hours / 24)}d`;
	}
</script>

<div class="flex h-full overflow-hidden">
	<!-- Left panel: Email list -->
	<div class="w-96 shrink-0 flex flex-col border-r border-border bg-base overflow-hidden">
		<div class="px-4 py-3 border-b border-border bg-surface shrink-0">
			<div class="flex items-center justify-between mb-1">
				<h2 class="text-sm font-display font-bold text-text-primary">Inbox</h2>
				<div class="flex gap-1.5">
					<button
						onclick={handlePurge}
						class="px-2 py-1 text-[10px] font-mono text-warning border border-warning/30 rounded hover:bg-warning/10 transition-colors"
						title="Purge all emails"
					>
						Purge
					</button>
					<button
						onclick={handleDeleteInbox}
						class="px-2 py-1 text-[10px] font-mono text-error border border-error/30 rounded hover:bg-error/10 transition-colors"
						title="Delete inbox"
					>
						Delete
					</button>
				</div>
			</div>
			{#if pagination}
				<p class="text-[10px] font-mono text-text-dim">{pagination.total_count} emails</p>
			{/if}
		</div>

		<div class="flex-1 overflow-y-auto">
			{#if loading}
				<div class="flex items-center justify-center h-full">
					<p class="text-text-dim font-mono text-xs">Loading emails...</p>
				</div>
			{:else if emails.length === 0}
				<div class="flex flex-col items-center justify-center h-full px-4">
					<span class="material-symbols-outlined text-4xl text-text-dim mb-3">mail</span>
					<p class="text-text-secondary font-mono text-xs text-center">No emails yet.<br />Waiting for incoming mail...</p>
				</div>
			{:else}
				<div class="divide-y divide-border">
					{#each emails as email (email.id)}
						<button
							onclick={() => selectEmail(email.id)}
							class="w-full text-left px-4 py-3 transition-colors cursor-pointer
								{selectedEmailId === email.id
								? 'bg-phosphor-glow border-l-2 border-l-phosphor'
								: 'hover:bg-surface-2 border-l-2 border-l-transparent'}"
						>
							<div class="flex items-center gap-2 mb-0.5">
								{#if newEmailIds.has(email.id)}
									<span class="size-1.5 rounded-full bg-phosphor shrink-0"></span>
								{/if}
								<span class="text-xs font-mono text-text-secondary truncate flex-1">{email.from}</span>
								<span class="text-[10px] font-mono text-text-dim shrink-0">{timeAgo(email.received_at)}</span>
							</div>
							<p class="text-sm text-text-primary truncate leading-tight {selectedEmailId === email.id ? 'font-medium' : ''}">
								{email.subject || '(no subject)'}
							</p>
							<p class="text-xs text-text-dim mt-0.5 truncate">{email.preview}</p>
						</button>
					{/each}
				</div>

				{#if pagination?.has_more}
					<div class="p-3 text-center border-t border-border">
						<button
							onclick={loadMore}
							disabled={loadingMore}
							class="text-xs font-mono text-phosphor hover:underline disabled:opacity-50"
						>
							{loadingMore ? 'Loading...' : 'Load more'}
						</button>
					</div>
				{/if}
			{/if}
		</div>
	</div>

	<!-- Right panel -->
	<div class="flex-1 overflow-hidden bg-base">
		{#if selectedEmailId}
			<EmailPreview
				emailId={selectedEmailId}
				{projectId}
				{inboxId}
				onDeleted={handleEmailDeleted}
			/>
		{:else}
			<div class="flex flex-col items-center justify-center h-full text-text-dim">
				<span class="material-symbols-outlined text-6xl mb-4">mark_email_read</span>
				<p class="font-mono text-sm">Select an email to preview</p>
			</div>
		{/if}
	</div>
</div>
