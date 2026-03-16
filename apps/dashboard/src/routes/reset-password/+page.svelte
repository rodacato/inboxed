<script lang="ts">
	import { page } from '$app/stores';
	import { resetPassword, getErrorMessage } from '../../features/auth/auth.service';

	let password = $state('');
	let confirmPassword = $state('');
	let error = $state('');
	let loading = $state(false);
	let success = $state(false);

	const token = $derived($page.url.searchParams.get('token') ?? '');

	async function handleSubmit() {
		if (!password || !token) return;
		if (password !== confirmPassword) {
			error = 'Passwords do not match.';
			return;
		}
		if (password.length < 8) {
			error = 'Password must be at least 8 characters.';
			return;
		}
		loading = true;
		error = '';

		try {
			await resetPassword(token, password);
			success = true;
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
			<p class="text-text-secondary text-sm mt-2 font-mono">Set a new password</p>
		</div>

		{#if success}
			<div class="bg-surface border border-border rounded-lg p-6 text-center">
				<span class="material-symbols-outlined text-phosphor text-3xl mb-3">check_circle</span>
				<h2 class="text-text-primary font-display font-bold text-lg mb-2">Password reset</h2>
				<p class="text-text-secondary text-sm font-mono mb-4">Your password has been updated.</p>
				<a href="/login" class="text-phosphor text-sm font-mono hover:underline">Sign in</a>
			</div>
		{:else if !token}
			<div class="bg-surface border border-border rounded-lg p-6 text-center">
				<p class="text-text-secondary text-sm font-mono">Invalid or missing reset token.</p>
				<a href="/forgot-password" class="inline-block mt-4 text-phosphor text-sm font-mono hover:underline">
					Request a new link
				</a>
			</div>
		{:else}
			<form onsubmit={e => { e.preventDefault(); handleSubmit(); }}>
				<label class="block mb-2 text-xs font-mono text-text-dim uppercase tracking-widest" for="rp-password">
					New Password
				</label>
				<input
					id="rp-password"
					type="password"
					bind:value={password}
					placeholder="Min. 8 characters"
					autocomplete="new-password"
					class="w-full bg-surface border border-border rounded px-4 py-3 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
				/>

				<label class="block mb-2 mt-4 text-xs font-mono text-text-dim uppercase tracking-widest" for="rp-confirm">
					Confirm Password
				</label>
				<input
					id="rp-confirm"
					type="password"
					bind:value={confirmPassword}
					placeholder="Repeat password"
					autocomplete="new-password"
					class="w-full bg-surface border border-border rounded px-4 py-3 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
				/>

				{#if error}
					<p class="text-error text-xs font-mono mt-2">{error}</p>
				{/if}

				<button
					type="submit"
					disabled={loading || !password || !confirmPassword}
					class="w-full mt-4 bg-phosphor text-base font-mono font-bold py-3 rounded text-sm uppercase tracking-wider hover:brightness-110 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
				>
					{loading ? 'Resetting...' : 'Reset password'}
				</button>
			</form>
		{/if}
	</div>
</div>
