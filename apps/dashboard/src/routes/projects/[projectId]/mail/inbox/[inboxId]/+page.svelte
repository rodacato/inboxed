<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { fetchEmails, purgeInbox } from '../../../../../../features/emails/emails.service';
	import { deleteInbox } from '../../../../../../features/inboxes/inboxes.service';
	import { getRealtimeStore } from '../../../../../../features/realtime/realtime.store.svelte';
	import { toastStore } from '$lib/stores/toast.store.svelte';
	import type { EmailSummary } from '../../../../../../features/emails/emails.types';
	import type { Pagination } from '../../../../../../features/projects/projects.types';
	import SplitPane from '$lib/components/SplitPane.svelte';
	import FilterableList from '$lib/components/FilterableList.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
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

	$effect(() => {
		const pid = projectId;
		const iid = inboxId;
		if (!pid || !iid) return;

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
				toastStore.add({
					type: 'success',
					title: 'New email received',
					description: `${email.subject || '(no subject)'}`
				});
			} else if (msg.type === 'email_deleted') {
				const wasSelected = selectedEmailId === msg.email_id;
				emails = emails.filter((e) => e.id !== msg.email_id);
				if (wasSelected) {
					selectedEmailId = emails.length > 0 ? emails[0].id : null;
				}
			} else if (msg.type === 'inbox_purged') {
				emails = [];
				selectedEmailId = null;
				toastStore.add({ type: 'info', title: 'Inbox purged' });
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
		goto(`/projects/${projectId}/mail`);
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

<SplitPane showDetail={!!selectedEmailId}>
	{#snippet list()}
		<FilterableList
			title="Inbox"
			totalCount={pagination?.total_count}
			hasMore={pagination?.has_more ?? false}
			{loadingMore}
			onLoadMore={loadMore}
			{loading}
		>
			{#snippet headerActions()}
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
			{/snippet}

			{#snippet items()}
				{#if emails.length === 0}
					<EmptyState icon="mail" title="No emails yet" description="Waiting for incoming mail..." />
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
									<span class="text-xs font-mono text-text-secondary truncate flex-1"
										>{email.from}</span
									>
									<span class="text-[10px] font-mono text-text-dim shrink-0"
										>{timeAgo(email.received_at)}</span
									>
								</div>
								<p
									class="text-sm text-text-primary truncate leading-tight {selectedEmailId ===
									email.id
										? 'font-medium'
										: ''}"
								>
									{email.subject || '(no subject)'}
								</p>
								<p class="text-xs text-text-dim mt-0.5 truncate">{email.preview}</p>
							</button>
						{/each}
					</div>
				{/if}
			{/snippet}
		</FilterableList>
	{/snippet}

	{#snippet detail()}
		{#if selectedEmailId}
			<EmailPreview
				emailId={selectedEmailId}
				{projectId}
				{inboxId}
				onDeleted={handleEmailDeleted}
			/>
		{/if}
	{/snippet}

	{#snippet empty()}
		<EmptyState icon="mark_email_read" title="Select an email to preview" />
	{/snippet}
</SplitPane>
