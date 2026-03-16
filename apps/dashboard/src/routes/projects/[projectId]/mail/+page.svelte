<script lang="ts">
	import { page } from '$app/stores';
	import { fetchProjectEmails } from '../../../../features/emails/emails.service';
	import { fetchInboxes } from '../../../../features/inboxes/inboxes.service';
	import { getRealtimeStore } from '../../../../features/realtime/realtime.store.svelte';
	import { toastStore } from '$lib/stores/toast.store.svelte';
	import type { EmailSummary } from '../../../../features/emails/emails.types';
	import type { Inbox } from '../../../../features/inboxes/inboxes.types';
	import type { Pagination } from '../../../../features/projects/projects.types';
	import SplitPane from '$lib/components/SplitPane.svelte';
	import FilterableList from '$lib/components/FilterableList.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import EmailPreview from '$lib/components/EmailPreview.svelte';

	const projectId = $derived($page.params.projectId ?? '');
	const realtime = getRealtimeStore();

	let emails = $state<EmailSummary[]>([]);
	let inboxes = $state<Inbox[]>([]);
	let pagination = $state<Pagination | null>(null);
	let loading = $state(true);
	let loadingMore = $state(false);
	let selectedEmailId = $state<string | null>(null);
	let selectedInboxFilter = $state<string | null>(null);
	let newEmailIds = $state(new Set<string>());
	let unsubscribers: (() => void)[] = [];

	$effect(() => {
		const pid = projectId;
		if (!pid) return;

		emails = [];
		inboxes = [];
		pagination = null;
		loading = true;
		selectedEmailId = null;
		selectedInboxFilter = null;
		newEmailIds = new Set();

		for (const unsub of unsubscribers) unsub();
		unsubscribers = [];

		loadProject(pid);
	});

	async function loadProject(pid: string) {
		const [emailsRes, inboxesRes] = await Promise.all([
			fetchProjectEmails(pid),
			fetchInboxes(pid)
		]);
		if (pid !== projectId) return;

		emails = emailsRes.emails;
		pagination = emailsRes.pagination;
		inboxes = inboxesRes.inboxes;
		loading = false;

		if (emails.length > 0) {
			selectedEmailId = emails[0].id;
		}

		for (const inbox of inboxesRes.inboxes) {
			const unsub = realtime.subscribeToInbox(inbox.id, (msg) => {
				if (msg.type === 'email_received') {
					const email = msg.email as EmailSummary;
					if (!email.inbox_address) {
						email.inbox_address = inbox.address;
					}
					emails = [email, ...emails];
					newEmailIds = new Set([...newEmailIds, email.id]);
					selectedEmailId = email.id;
					toastStore.add({
						type: 'success',
						title: 'New email received',
						description: `${email.subject || '(no subject)'}`,
						action: { label: 'View', href: `/projects/${projectId}/mail/${email.id}` }
					});
				} else if (msg.type === 'email_deleted') {
					const wasSelected = selectedEmailId === msg.email_id;
					emails = emails.filter((e) => e.id !== msg.email_id);
					if (wasSelected) {
						selectedEmailId = filteredEmails.length > 0 ? filteredEmails[0].id : null;
					}
				} else if (msg.type === 'inbox_purged') {
					emails = emails.filter((e) => e.inbox_address !== inbox.address);
					if (selectedEmailId && !emails.find((e) => e.id === selectedEmailId)) {
						selectedEmailId = emails.length > 0 ? emails[0].id : null;
					}
					toastStore.add({
						type: 'info',
						title: 'Inbox purged',
						description: `${inbox.address}`
					});
				}
			});
			unsubscribers.push(unsub);
		}
	}

	const filteredEmails = $derived(
		selectedInboxFilter
			? emails.filter((e) => e.inbox_address === selectedInboxFilter)
			: emails
	);

	const inboxFilters = $derived.by(() => {
		const addresses = new Set<string>();
		for (const e of emails) {
			if (e.inbox_address) addresses.add(e.inbox_address);
		}
		return [...addresses].sort().map((addr) => ({
			id: addr,
			label: addr.indexOf('@') > 0 ? addr.substring(0, addr.indexOf('@')) : addr
		}));
	});

	async function loadMore() {
		if (!pagination?.has_more || !pagination.next_cursor) return;
		loadingMore = true;
		const res = await fetchProjectEmails(projectId, {
			after: pagination.next_cursor,
			inbox_id: selectedInboxFilter
				? inboxes.find((i) => i.address === selectedInboxFilter)?.id
				: undefined
		});
		emails = [...emails, ...res.emails];
		pagination = res.pagination;
		loadingMore = false;
	}

	function selectEmail(id: string) {
		selectedEmailId = id;
		if (newEmailIds.has(id)) {
			const next = new Set(newEmailIds);
			next.delete(id);
			newEmailIds = next;
		}
	}

	function setInboxFilter(address: string | null) {
		selectedInboxFilter = address;
		const list = address ? emails.filter((e) => e.inbox_address === address) : emails;
		selectedEmailId = list.length > 0 ? list[0].id : null;
	}

	function handleEmailDeleted() {
		emails = emails.filter((e) => e.id !== selectedEmailId);
		const list = filteredEmails;
		selectedEmailId = list.length > 0 ? list[0].id : null;
	}

	function inboxColor(address: string): string {
		const colors = [
			'bg-phosphor/15 text-phosphor',
			'bg-cyan/15 text-cyan',
			'bg-amber/15 text-amber',
			'bg-error/15 text-error',
			'bg-info/15 text-info',
			'bg-text-secondary/15 text-text-secondary'
		];
		let hash = 0;
		for (let i = 0; i < address.length; i++) {
			hash = ((hash << 5) - hash + address.charCodeAt(i)) | 0;
		}
		return colors[Math.abs(hash) % colors.length];
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
			title="Emails"
			totalCount={pagination?.total_count}
			filters={inboxFilters}
			activeFilter={selectedInboxFilter}
			onFilterChange={setInboxFilter}
			hasMore={pagination?.has_more ?? false}
			{loadingMore}
			onLoadMore={loadMore}
			{loading}
		>
			{#snippet items()}
				{#if filteredEmails.length === 0}
					<EmptyState icon="mail" title="No emails yet" description="Waiting for incoming mail... Configure your app's SMTP to point at Inboxed." />
				{:else}
					<div class="divide-y divide-border">
						{#each filteredEmails as email (email.id)}
							<button
								onclick={() => selectEmail(email.id)}
								class="w-full text-left px-4 py-3 transition-colors cursor-pointer
									{selectedEmailId === email.id
									? 'bg-phosphor-glow border-l-2 border-l-phosphor'
									: 'hover:bg-surface-2 border-l-2 border-l-transparent'}"
							>
								<div class="flex items-center gap-1.5 mb-0.5">
									{#if newEmailIds.has(email.id)}
										<span class="size-1.5 rounded-full bg-phosphor shrink-0"></span>
									{/if}
									{#if email.inbox_address && !selectedInboxFilter}
										<span
											class="px-1.5 py-0 rounded text-[9px] font-mono font-medium {inboxColor(email.inbox_address)}"
										>
											{email.inbox_address.indexOf('@') > 0 ? email.inbox_address.substring(0, email.inbox_address.indexOf('@')) : email.inbox_address}
										</span>
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
				inboxId=""
				onDeleted={handleEmailDeleted}
			/>
		{/if}
	{/snippet}

	{#snippet empty()}
		<EmptyState icon="mark_email_read" title="Select an email to preview" />
	{/snippet}
</SplitPane>
