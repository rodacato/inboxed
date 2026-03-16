<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { verifyEmail, resendVerification } from '../../features/auth/auth.service';

	let status = $state<'verifying' | 'success' | 'error' | 'no-token'>('verifying');
	let resendEmail = $state('');
	let resendSent = $state(false);
	let resendError = $state('');

	onMount(async () => {
		const token = $page.url.searchParams.get('token');
		if (!token) {
			status = 'no-token';
			return;
		}

		const ok = await verifyEmail(token);
		status = ok ? 'success' : 'error';
	});

	async function handleResend() {
		if (!resendEmail.trim()) return;
		resendError = '';
		try {
			await resendVerification(resendEmail);
			resendSent = true;
		} catch {
			resendError = 'Could not resend verification email.';
		}
	}
</script>

<div class="min-h-screen flex items-center justify-center bg-base">
	<div class="w-full max-w-sm p-8">
		<div class="text-center mb-10">
			<div class="font-mono text-phosphor text-4xl font-bold terminal-glow mb-3">[@]</div>
			<h1 class="font-display text-2xl font-bold text-text-primary tracking-tight">inboxed</h1>
		</div>

		<div class="bg-surface border border-border rounded-lg p-6 text-center">
			{#if status === 'verifying'}
				<p class="text-text-secondary font-mono text-sm">Verifying your email...</p>
			{:else if status === 'success'}
				<span class="material-symbols-outlined text-phosphor text-3xl mb-3">check_circle</span>
				<h2 class="text-text-primary font-display font-bold text-lg mb-2">Email verified</h2>
				<p class="text-text-secondary text-sm font-mono mb-4">Your account is now active.</p>
				<a href="/login" class="text-phosphor text-sm font-mono hover:underline">Sign in</a>
			{:else if status === 'error'}
				<span class="material-symbols-outlined text-error text-3xl mb-3">error</span>
				<h2 class="text-text-primary font-display font-bold text-lg mb-2">Verification failed</h2>
				<p class="text-text-secondary text-sm font-mono mb-4">This link may have expired or is invalid.</p>

				{#if resendSent}
					<p class="text-phosphor text-sm font-mono">Verification email resent.</p>
				{:else}
					<form onsubmit={e => { e.preventDefault(); handleResend(); }} class="mt-4">
						<input
							type="email"
							bind:value={resendEmail}
							placeholder="Your email"
							class="w-full bg-base border border-border rounded px-3 py-2 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
						/>
						{#if resendError}
							<p class="text-error text-xs font-mono mt-1">{resendError}</p>
						{/if}
						<button
							type="submit"
							disabled={!resendEmail.trim()}
							class="w-full mt-2 bg-surface-2 text-text-primary font-mono py-2 rounded text-sm hover:bg-surface transition-colors disabled:opacity-50"
						>
							Resend verification
						</button>
					</form>
				{/if}
			{:else}
				<p class="text-text-secondary text-sm font-mono">No verification token provided.</p>
				<a href="/login" class="inline-block mt-4 text-phosphor text-sm font-mono hover:underline">Back to login</a>
			{/if}
		</div>
	</div>
</div>
