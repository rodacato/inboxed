<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { onboardingStore, type SetupResult } from '$lib/stores/onboarding.store.svelte';

	let data = $state<SetupResult | null>(null);
	let copied = $state<string | null>(null);

	const smtpSnippet = $derived(
		data ? `SMTP_HOST=${data.smtp.host}\nSMTP_PORT=${data.smtp.port}\nSMTP_USERNAME=${data.project.slug}\nSMTP_PASSWORD=${data.apiKey.token}` : ''
	);
	const curlSnippet = $derived(
		data ? `curl --url "smtp://${data.smtp.host}:${data.smtp.port}" \\\n  --user "${data.project.slug}:${data.apiKey.token}" \\\n  --mail-from "test@example.com" \\\n  --mail-rcpt "hello@${data.project.slug}.test" \\\n  --upload-file - <<EOF\nFrom: test@example.com\nTo: hello@${data.project.slug}.test\nSubject: Hello from Inboxed\n\nYour first test email!\nEOF` : ''
	);

	onMount(() => {
		const result = onboardingStore.load();
		if (!result) {
			goto('/projects');
			return;
		}
		data = result;
	});

	async function copyToClipboard(text: string, key: string) {
		await navigator.clipboard.writeText(text);
		copied = key;
		setTimeout(() => { copied = null; }, 2000);
	}

	function goToDashboard() {
		onboardingStore.clear();
		goto('/projects');
	}

	$effect(() => {
		return () => onboardingStore.clear();
	});
</script>

{#if data}
<div class="min-h-screen flex items-center justify-center bg-base">
	<div class="w-full max-w-lg p-8">
		<div class="text-center mb-8">
			<div class="font-mono text-phosphor text-4xl font-bold terminal-glow mb-3">[@]</div>
			<h1 class="font-display text-2xl font-bold text-text-primary tracking-tight">You're all set</h1>
			<p class="text-text-secondary text-sm mt-2 font-mono">Your Inboxed instance is ready to catch emails.</p>
		</div>

		<!-- What was created -->
		<div class="space-y-4 mb-8">
			<div class="p-4 rounded-lg border border-border bg-surface">
				<h3 class="text-xs font-mono text-text-dim uppercase tracking-widest mb-3">Created for you</h3>
				<div class="space-y-2 text-sm font-mono">
					<div class="flex justify-between">
						<span class="text-text-secondary">Project</span>
						<span class="text-text-primary">{data.project.name}</span>
					</div>
					<div class="flex justify-between">
						<span class="text-text-secondary">Slug</span>
						<span class="text-text-primary">{data.project.slug}</span>
					</div>
				</div>
			</div>

			<!-- API Key (shown once) -->
			<div class="p-4 rounded-lg border border-amber/30 bg-amber/5">
				<div class="flex items-center gap-2 mb-3">
					<span class="material-symbols-outlined text-amber text-base">key</span>
					<h3 class="text-xs font-mono text-amber uppercase tracking-widest">API Key — save this now</h3>
				</div>
				<p class="text-xs text-text-secondary font-mono mb-3">This token is shown only once. Copy it before continuing.</p>
				<div class="flex items-center gap-2">
					<code class="flex-1 bg-surface-2 border border-border rounded px-3 py-2 text-xs font-mono text-text-primary break-all select-all">
						{data.apiKey.token}
					</code>
					<button
						onclick={() => copyToClipboard(data!.apiKey.token, 'apikey')}
						class="shrink-0 px-3 py-2 bg-surface-2 border border-border rounded text-xs font-mono text-text-secondary hover:text-text-primary hover:border-phosphor transition-colors"
					>
						{copied === 'apikey' ? 'Copied!' : 'Copy'}
					</button>
				</div>
			</div>

			<!-- SMTP Config -->
			<div class="p-4 rounded-lg border border-border bg-surface">
				<div class="flex items-center gap-2 mb-3">
					<span class="material-symbols-outlined text-phosphor text-base">mail</span>
					<h3 class="text-xs font-mono text-text-dim uppercase tracking-widest">SMTP Configuration</h3>
				</div>
				<p class="text-xs text-text-secondary font-mono mb-3">Point your app's SMTP config here to start catching emails.</p>
				<div class="relative">
					<pre class="bg-surface-2 border border-border rounded px-3 py-2 text-xs font-mono text-text-primary overflow-x-auto">{smtpSnippet}</pre>
					<button
						onclick={() => copyToClipboard(smtpSnippet, 'smtp')}
						class="absolute top-2 right-2 px-2 py-1 bg-surface border border-border rounded text-xs font-mono text-text-secondary hover:text-text-primary hover:border-phosphor transition-colors"
					>
						{copied === 'smtp' ? 'Copied!' : 'Copy'}
					</button>
				</div>
			</div>

			<!-- Quick test -->
			<div class="p-4 rounded-lg border border-border bg-surface">
				<div class="flex items-center gap-2 mb-3">
					<span class="material-symbols-outlined text-cyan text-base">terminal</span>
					<h3 class="text-xs font-mono text-text-dim uppercase tracking-widest">Send a test email</h3>
				</div>
				<div class="relative">
					<pre class="bg-surface-2 border border-border rounded px-3 py-2 text-xs font-mono text-text-primary overflow-x-auto">{curlSnippet}</pre>
					<button
						onclick={() => copyToClipboard(curlSnippet, 'curl')}
						class="absolute top-2 right-2 px-2 py-1 bg-surface border border-border rounded text-xs font-mono text-text-secondary hover:text-text-primary hover:border-phosphor transition-colors"
					>
						{copied === 'curl' ? 'Copied!' : 'Copy'}
					</button>
				</div>
			</div>
		</div>

		<button
			onclick={goToDashboard}
			class="w-full bg-phosphor text-base font-mono font-bold py-3 rounded text-sm uppercase tracking-wider hover:brightness-110 transition-all"
		>
			Go to dashboard
		</button>
	</div>
</div>
{/if}
