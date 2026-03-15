<script lang="ts">
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { fetchEmail, fetchEmailRaw, deleteEmail } from '../../../../../features/emails/emails.service';
	import type { EmailDetail } from '../../../../../features/emails/emails.types';

	const projectId = $derived($page.params.projectId);
	const emailId = $derived($page.params.emailId);

	let email = $state<EmailDetail | null>(null);
	let loading = $state(true);
	let activeTab = $state<'html' | 'text' | 'raw' | 'headers'>('html');
	let rawSource = $state<string | null>(null);
	let loadingRaw = $state(false);
	let copied = $state(false);

	onMount(async () => {
		const res = await fetchEmail(emailId);
		email = res.email;
		if (!email.body_html && email.body_text) activeTab = 'text';
		loading = false;
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
		goto(`/projects/${projectId}/inboxes/${email?.inbox_id}`);
	}

	// OTP Detection
	const otpCode = $derived.by(() => {
		if (!email) return null;
		const text = `${email.subject ?? ''} ${email.body_text ?? ''}`;
		// Labeled codes
		const labeled = text.match(/(?:code|otp|pin|token|verification)[:\s]+([A-Z0-9][A-Z0-9-]{2,11})/i);
		if (labeled) return labeled[1];
		// Alphanumeric with dashes (e.g., 8829-X)
		const dashed = text.match(/\b([A-Z0-9]{4,6}-[A-Z0-9]{1,6})\b/);
		if (dashed) return dashed[1];
		// Numeric 4-8 digits
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
	<div class="p-8">
		<p class="text-text-dim font-mono text-sm">Loading...</p>
	</div>
{:else if email}
	<div class="p-8 max-w-5xl">
		<!-- Breadcrumb -->
		<div class="flex items-center gap-2 text-sm font-mono text-text-secondary mb-6">
			<a href="/projects" class="hover:text-phosphor">Projects</a>
			<span class="text-text-dim">/</span>
			<a href="/projects/{projectId}" class="hover:text-phosphor">Project</a>
			<span class="text-text-dim">/</span>
			<a href="/projects/{projectId}/inboxes/{email.inbox_id}" class="hover:text-phosphor"
				>Inbox</a
			>
			<span class="text-text-dim">/</span>
			<span class="text-text-primary truncate max-w-48">{email.subject || '(no subject)'}</span>
		</div>

		<!-- OTP Banner -->
		{#if otpCode}
			<div
				class="mb-6 p-4 rounded-lg border border-phosphor/30 bg-phosphor-glow flex items-center justify-between"
			>
				<div class="flex items-center gap-3">
					<span class="material-symbols-outlined text-phosphor">pin</span>
					<span class="text-sm font-mono text-text-primary"
						>OTP Detected: <strong class="text-phosphor">{otpCode}</strong></span
					>
				</div>
				<button
					onclick={copyOtp}
					class="px-3 py-1.5 bg-phosphor text-base rounded text-xs font-mono font-medium hover:brightness-110"
				>
					{copied ? 'Copied!' : 'Copy'}
				</button>
			</div>
		{/if}

		<!-- Header -->
		<div class="flex items-start justify-between mb-6">
			<div>
				<h2 class="text-xl font-display font-bold text-text-primary">
					{email.subject || '(no subject)'}
				</h2>
			</div>
			<button
				onclick={handleDelete}
				class="px-3 py-1.5 text-xs font-mono text-error border border-error/30 rounded hover:bg-error/10 transition-colors"
			>
				Delete
			</button>
		</div>

		<!-- Metadata -->
		<div class="mb-6 p-4 rounded-lg bg-surface border border-border space-y-2 text-sm font-mono">
			<div class="flex gap-3">
				<span class="text-text-dim w-16 shrink-0">From:</span>
				<span class="text-text-primary">{email.from}</span>
			</div>
			<div class="flex gap-3">
				<span class="text-text-dim w-16 shrink-0">To:</span>
				<span class="text-text-primary">{email.to.join(', ')}</span>
			</div>
			{#if email.cc.length > 0}
				<div class="flex gap-3">
					<span class="text-text-dim w-16 shrink-0">CC:</span>
					<span class="text-text-primary">{email.cc.join(', ')}</span>
				</div>
			{/if}
			<div class="flex gap-3">
				<span class="text-text-dim w-16 shrink-0">Date:</span>
				<span class="text-text-primary">{formatDate(email.received_at)}</span>
			</div>
		</div>

		<!-- Tabs -->
		<div class="border-b border-border mb-4 flex gap-0">
			{#each ['html', 'text', 'raw', 'headers'] as tab (tab)}
				<button
					onclick={() => handleTabChange(tab as typeof activeTab)}
					class="px-4 py-2 text-sm font-mono transition-colors border-b-2 -mb-px
						{activeTab === tab
						? 'border-phosphor text-phosphor'
						: 'border-transparent text-text-secondary hover:text-text-primary'}"
				>
					{tab.charAt(0).toUpperCase() + tab.slice(1)}
				</button>
			{/each}
		</div>

		<!-- Tab Content -->
		<div class="rounded-lg border border-border bg-surface overflow-hidden">
			{#if activeTab === 'html'}
				{#if email.body_html}
					<iframe
						srcdoc={email.body_html}
						sandbox="allow-same-origin"
						title="Email HTML preview"
						class="w-full min-h-[400px] border-0"
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
						class="absolute top-3 right-3 px-2 py-1 text-xs font-mono text-text-secondary bg-surface-2 rounded border border-border hover:text-text-primary"
					>
						Copy
					</button>
					{#if loadingRaw}
						<p class="p-6 text-text-dim font-mono text-sm">Loading raw source...</p>
					{:else if rawSource}
						<pre class="p-6 text-xs font-mono text-text-secondary whitespace-pre-wrap overflow-x-auto max-h-[600px] overflow-y-auto">{rawSource}</pre>
					{/if}
				</div>
			{:else if activeTab === 'headers'}
				<div class="p-6">
					{#if email.raw_headers && Object.keys(email.raw_headers).length > 0}
						<table class="w-full text-sm">
							<tbody>
								{#each Object.entries(email.raw_headers) as [key, value] (key)}
									<tr class="border-b border-border last:border-0">
										<td class="py-2 pr-4 font-mono text-text-dim align-top whitespace-nowrap"
											>{key}</td
										>
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
			<section class="mt-6">
				<h3 class="text-sm font-mono font-bold text-text-primary mb-3">
					Attachments ({email.attachments.length})
				</h3>
				<div class="space-y-2">
					{#each email.attachments as att (att.id)}
						<div
							class="flex items-center justify-between p-3 rounded-lg bg-surface border border-border"
						>
							<div class="flex items-center gap-3">
								<span class="material-symbols-outlined text-text-dim">attach_file</span>
								<div>
									<p class="text-sm font-mono text-text-primary">{att.filename}</p>
									<p class="text-xs font-mono text-text-dim">
										{att.content_type} · {formatSize(att.size_bytes)}
										{#if att.inline}<span class="text-cyan ml-1">(inline)</span>{/if}
									</p>
								</div>
							</div>
							<a
								href={att.download_url}
								class="px-3 py-1.5 text-xs font-mono text-phosphor border border-phosphor/30 rounded hover:bg-phosphor-glow transition-colors"
							>
								Download
							</a>
						</div>
					{/each}
				</div>
			</section>
		{/if}

		<!-- Expiry -->
		<div class="mt-6 text-xs font-mono text-text-dim">
			Expires: {formatDate(email.expires_at)}
		</div>
	</div>
{/if}
