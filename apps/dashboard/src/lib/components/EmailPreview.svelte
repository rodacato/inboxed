<script lang="ts">
	import { fetchEmail, fetchEmailRaw, deleteEmail } from '../../features/emails/emails.service';
	import type { EmailDetail } from '../../features/emails/emails.types';

	let {
		emailId,
		onDeleted
	}: {
		emailId: string;
		projectId?: string;
		inboxId?: string;
		onDeleted?: () => void;
	} = $props();

	let email = $state<EmailDetail | null>(null);
	let loading = $state(true);
	let activeTab = $state<'html' | 'text' | 'raw' | 'headers'>('html');
	let rawSource = $state<string | null>(null);
	let loadingRaw = $state(false);
	let copied = $state(false);

	$effect(() => {
		// Re-fetch when emailId changes
		const id = emailId;
		loading = true;
		activeTab = 'html';
		rawSource = null;
		email = null;

		fetchEmail(id).then((res) => {
			email = res.email;
			if (!email.body_html && email.body_text) activeTab = 'text';
			loading = false;
		});
	});

	async function loadRaw() {
		if (rawSource !== null) return;
		loadingRaw = true;
		rawSource = await fetchEmailRaw(emailId);
		loadingRaw = false;
	}

	function handleTabChange(tab: typeof activeTab) {
		activeTab = tab;
		if (tab === 'raw') loadRaw();
	}

	async function handleDelete() {
		if (!confirm('Delete this email?')) return;
		await deleteEmail(emailId);
		onDeleted?.();
	}

	// OTP Detection
	const otpCode = $derived.by(() => {
		if (!email) return null;
		const text = `${email.subject ?? ''} ${email.body_text ?? ''}`;
		const labeled = text.match(/(?:code|otp|pin|token|verification)[:\s]+([A-Z0-9][A-Z0-9-]{2,11})/i);
		if (labeled) return labeled[1];
		const dashed = text.match(/\b([A-Z0-9]{4,6}-[A-Z0-9]{1,6})\b/);
		if (dashed) return dashed[1];
		const numeric = text.match(/\b(\d{4,8})\b/);
		if (numeric) return numeric[1];
		return null;
	});

	function copyOtp() {
		if (otpCode) {
			navigator.clipboard.writeText(otpCode);
			copied = true;
			setTimeout(() => (copied = false), 2000);
		}
	}

	function copyRaw() {
		if (rawSource) navigator.clipboard.writeText(rawSource);
	}

	function formatSize(bytes: number): string {
		if (bytes < 1024) return `${bytes} B`;
		if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
		return `${(bytes / 1048576).toFixed(1)} MB`;
	}

	function formatDate(iso: string): string {
		return new Date(iso).toLocaleString();
	}
</script>

{#if loading}
	<div class="flex items-center justify-center h-full">
		<p class="text-text-dim font-mono text-sm">Loading email...</p>
	</div>
{:else if email}
	<div class="flex flex-col h-full overflow-hidden">
		<!-- OTP Banner -->
		{#if otpCode}
			<div class="mx-6 mt-4 p-3 rounded-lg border border-phosphor/30 bg-phosphor-glow flex items-center justify-between shrink-0">
				<div class="flex items-center gap-3">
					<span class="material-symbols-outlined text-phosphor text-lg">pin</span>
					<span class="text-sm font-mono text-text-primary">
						OTP Detected: <strong class="text-phosphor">{otpCode}</strong>
					</span>
				</div>
				<button
					onclick={copyOtp}
					class="px-3 py-1 bg-phosphor text-base rounded text-xs font-mono font-medium hover:brightness-110"
				>
					{copied ? 'Copied!' : 'Copy'}
				</button>
			</div>
		{/if}

		<!-- Header + Metadata -->
		<div class="px-6 pt-4 pb-3 shrink-0 border-b border-border">
			<div class="flex items-start justify-between mb-3">
				<h2 class="text-lg font-display font-bold text-text-primary leading-tight pr-4">
					{email.subject || '(no subject)'}
				</h2>
				<button
					onclick={handleDelete}
					class="px-2.5 py-1 text-xs font-mono text-error border border-error/30 rounded hover:bg-error/10 transition-colors shrink-0"
				>
					Delete
				</button>
			</div>

			<!-- Metadata inline -->
			<div class="flex flex-wrap gap-x-6 gap-y-1 text-xs font-mono text-text-secondary">
				<span><span class="text-text-dim">From:</span> {email.from}</span>
				<span><span class="text-text-dim">To:</span> {email.to.join(', ')}</span>
				{#if email.cc.length > 0}
					<span><span class="text-text-dim">CC:</span> {email.cc.join(', ')}</span>
				{/if}
				<span><span class="text-text-dim">Date:</span> {formatDate(email.received_at)}</span>
				<span class="text-text-dim">Expires: {formatDate(email.expires_at)}</span>
			</div>
		</div>

		<!-- Tabs -->
		<div class="flex border-b border-border shrink-0 px-6 gap-0 bg-surface">
			{#each ['html', 'text', 'raw', 'headers'] as tab (tab)}
				<button
					onclick={() => handleTabChange(tab as typeof activeTab)}
					class="px-4 py-2.5 text-xs font-mono uppercase tracking-wide transition-colors border-b-2 -mb-px
						{activeTab === tab
						? 'border-phosphor text-phosphor'
						: 'border-transparent text-text-secondary hover:text-text-primary'}"
				>
					{tab}
				</button>
			{/each}
		</div>

		<!-- Tab Content — fills remaining space -->
		<div class="flex-1 overflow-auto bg-surface">
			{#if activeTab === 'html'}
				{#if email.body_html}
					<iframe
						srcdoc={email.body_html}
						sandbox="allow-same-origin"
						title="Email HTML preview"
						class="w-full h-full border-0"
						style="min-height: 400px;"
						onload={(e) => {
							const iframe = e.target as HTMLIFrameElement;
							const doc = iframe.contentDocument;
							if (doc) {
								iframe.style.height = doc.body.scrollHeight + 40 + 'px';
							}
						}}
					></iframe>
				{:else}
					<div class="p-6 text-text-dim font-mono text-sm">No HTML body</div>
				{/if}
			{:else if activeTab === 'text'}
				{#if email.body_text}
					<pre class="p-6 text-sm font-mono text-text-primary whitespace-pre-wrap">{email.body_text}</pre>
				{:else}
					<div class="p-6 text-text-dim font-mono text-sm">No text body</div>
				{/if}
			{:else if activeTab === 'raw'}
				<div class="relative">
					<button
						onclick={copyRaw}
						class="absolute top-3 right-3 px-2 py-1 text-xs font-mono text-text-secondary bg-surface-2 rounded border border-border hover:text-text-primary z-10"
					>
						Copy
					</button>
					{#if loadingRaw}
						<p class="p-6 text-text-dim font-mono text-sm">Loading raw source...</p>
					{:else if rawSource}
						<pre class="p-6 text-xs font-mono text-text-secondary whitespace-pre-wrap overflow-x-auto">{rawSource}</pre>
					{/if}
				</div>
			{:else if activeTab === 'headers'}
				<div class="p-6">
					{#if email.raw_headers && Object.keys(email.raw_headers).length > 0}
						<table class="w-full text-xs">
							<tbody>
								{#each Object.entries(email.raw_headers) as [key, value] (key)}
									<tr class="border-b border-border last:border-0">
										<td class="py-2 pr-4 font-mono text-text-dim align-top whitespace-nowrap font-medium">{key}</td>
										<td class="py-2 font-mono text-text-primary break-all">{value}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					{:else}
						<p class="text-text-dim font-mono text-sm">No headers available</p>
					{/if}
				</div>
			{/if}
		</div>

		<!-- Attachments -->
		{#if email.attachments.length > 0}
			<div class="px-6 py-4 border-t border-border shrink-0 bg-surface">
				<h3 class="text-xs font-mono font-bold text-text-primary mb-2">
					Attachments ({email.attachments.length})
				</h3>
				<div class="flex flex-wrap gap-2">
					{#each email.attachments as att (att.id)}
						<a
							href={att.download_url}
							class="flex items-center gap-2 px-3 py-2 rounded-lg bg-surface-2 border border-border hover:border-phosphor/30 transition-colors"
						>
							<span class="material-symbols-outlined text-text-dim text-sm">attach_file</span>
							<span class="text-xs font-mono text-text-primary">{att.filename}</span>
							<span class="text-xs font-mono text-text-dim">{formatSize(att.size_bytes)}</span>
						</a>
					{/each}
				</div>
			</div>
		{/if}
	</div>
{/if}
