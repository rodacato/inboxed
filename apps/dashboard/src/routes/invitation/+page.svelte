<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { getInvitation, acceptInvitation, getErrorMessage } from '../../features/auth/auth.service';

	let invitation = $state<{ email: string; organization_name: string; role: string; expires_at: string } | null>(null);
	let password = $state('');
	let error = $state('');
	let loading = $state(false);
	let loadError = $state('');
	let success = $state(false);

	const token = $derived($page.url.searchParams.get('token') ?? '');

	onMount(async () => {
		if (!token) {
			loadError = 'No invitation token provided.';
			return;
		}
		try {
			invitation = await getInvitation(token);
		} catch {
			loadError = 'This invitation is invalid or has expired.';
		}
	});

	async function handleAccept() {
		if (!password || !token) return;
		if (password.length < 8) {
			error = 'Password must be at least 8 characters.';
			return;
		}
		loading = true;
		error = '';

		try {
			await acceptInvitation(token, password);
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
		</div>

		{#if loadError}
			<div class="bg-surface border border-border rounded-lg p-6 text-center">
				<span class="material-symbols-outlined text-error text-3xl mb-3">error</span>
				<p class="text-text-secondary text-sm font-mono">{loadError}</p>
			</div>
		{:else if success}
			<div class="bg-surface border border-border rounded-lg p-6 text-center">
				<span class="material-symbols-outlined text-phosphor text-3xl mb-3">check_circle</span>
				<h2 class="text-text-primary font-display font-bold text-lg mb-2">You're in!</h2>
				<p class="text-text-secondary text-sm font-mono mb-4">
					You've joined <strong class="text-text-primary">{invitation?.organization_name}</strong>.
				</p>
				<a href="/login" class="text-phosphor text-sm font-mono hover:underline">Sign in</a>
			</div>
		{:else if invitation}
			<div class="bg-surface border border-border rounded-lg p-6 mb-6 text-center">
				<p class="text-text-secondary text-sm font-mono">
					You've been invited to join
				</p>
				<p class="text-text-primary font-display font-bold text-lg mt-1">{invitation.organization_name}</p>
				<p class="text-text-dim text-xs font-mono mt-2">
					as <span class="text-text-secondary">{invitation.role}</span>
				</p>
			</div>

			<form onsubmit={e => { e.preventDefault(); handleAccept(); }}>
				<label class="block mb-2 text-xs font-mono text-text-dim uppercase tracking-widest" for="inv-email">
					Email
				</label>
				<input
					id="inv-email"
					type="email"
					value={invitation.email}
					disabled
					class="w-full bg-surface border border-border rounded px-4 py-3 font-mono text-sm text-text-dim"
				/>

				<label class="block mb-2 mt-4 text-xs font-mono text-text-dim uppercase tracking-widest" for="inv-password">
					Choose a Password
				</label>
				<input
					id="inv-password"
					type="password"
					bind:value={password}
					placeholder="Min. 8 characters"
					autocomplete="new-password"
					class="w-full bg-surface border border-border rounded px-4 py-3 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
				/>

				{#if error}
					<p class="text-error text-xs font-mono mt-2">{error}</p>
				{/if}

				<button
					type="submit"
					disabled={loading || !password}
					class="w-full mt-4 bg-phosphor text-base font-mono font-bold py-3 rounded text-sm uppercase tracking-wider hover:brightness-110 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
				>
					{loading ? 'Joining...' : 'Accept invitation'}
				</button>
			</form>
		{:else}
			<p class="text-text-secondary text-sm font-mono text-center">Loading invitation...</p>
		{/if}
	</div>
</div>
