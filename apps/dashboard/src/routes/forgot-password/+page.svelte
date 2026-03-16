<script lang="ts">
	import { forgotPassword, getErrorMessage } from '../../features/auth/auth.service';

	let email = $state('');
	let error = $state('');
	let loading = $state(false);
	let sent = $state(false);

	async function handleSubmit() {
		if (!email.trim()) return;
		loading = true;
		error = '';

		try {
			await forgotPassword(email);
			sent = true;
		} catch (err) {
			error = getErrorMessage(err);
		} finally {
			loading = false;
		}
	}
</script>

<div class="min-h-screen flex items-center justify-center bg-base">
	<div class="w-full max-w-sm p-8">
		<div class="text-center mb-10">
			<div class="font-mono text-phosphor text-4xl font-bold terminal-glow mb-3">[@]</div>
			<h1 class="font-display text-2xl font-bold text-text-primary tracking-tight">inboxed</h1>
			<p class="text-text-secondary text-sm mt-2 font-mono">Reset your password</p>
		</div>

		{#if sent}
			<div class="bg-surface border border-border rounded-lg p-6 text-center">
				<span class="material-symbols-outlined text-phosphor text-3xl mb-3">mark_email_read</span>
				<h2 class="text-text-primary font-display font-bold text-lg mb-2">Check your email</h2>
				<p class="text-text-secondary text-sm font-mono">
					If an account exists for <strong class="text-text-primary">{email}</strong>, we sent a password reset link.
				</p>
				<a href="/login" class="inline-block mt-4 text-phosphor text-sm font-mono hover:underline">
					Back to login
				</a>
			</div>
		{:else}
			<form onsubmit={e => { e.preventDefault(); handleSubmit(); }}>
				<label class="block mb-2 text-xs font-mono text-text-dim uppercase tracking-widest" for="fp-email">
					Email
				</label>
				<input
					id="fp-email"
					type="email"
					bind:value={email}
					placeholder="you@example.com"
					autocomplete="email"
					class="w-full bg-surface border border-border rounded px-4 py-3 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
				/>

				{#if error}
					<p class="text-error text-xs font-mono mt-2">{error}</p>
				{/if}

				<button
					type="submit"
					disabled={loading || !email.trim()}
					class="w-full mt-4 bg-phosphor text-base font-mono font-bold py-3 rounded text-sm uppercase tracking-wider hover:brightness-110 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
				>
					{loading ? 'Sending...' : 'Send reset link'}
				</button>
			</form>

			<p class="mt-6 text-center text-xs font-mono text-text-dim">
				<a href="/login" class="text-text-secondary hover:text-phosphor hover:underline">Back to login</a>
			</p>
		{/if}
	</div>
</div>
