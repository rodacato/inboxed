<script lang="ts">
	import { goto } from '$app/navigation';
	import { setup, getErrorMessage } from '../../features/auth/auth.service';
	import { onboardingStore } from '$lib/stores/onboarding.store.svelte';

	let setupToken = $state('');
	let orgName = $state('');
	let email = $state('');
	let password = $state('');
	let error = $state('');
	let loading = $state(false);

	async function handleSetup() {
		if (!setupToken.trim() || !email.trim() || !password) return;
		loading = true;
		error = '';

		try {
			const result = await setup(setupToken, orgName || `${email.split('@')[0]}'s workspace`, email, password);
			onboardingStore.set({
				project: result.project,
				apiKey: {
					id: result.api_key.id,
					token: result.api_key.token,
					tokenPrefix: result.api_key.token_prefix,
					label: result.api_key.label
				},
				smtp: result.smtp
			});
			goto('/setup/complete');
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
			<p class="text-text-secondary text-sm mt-2 font-mono">Welcome. Let's set up your instance.</p>
		</div>

		<form onsubmit={e => { e.preventDefault(); handleSetup(); }}>
			<label class="block mb-2 text-xs font-mono text-text-dim uppercase tracking-widest" for="setup-token">
				Setup Token
			</label>
			<input
				id="setup-token"
				type="password"
				bind:value={setupToken}
				placeholder="From INBOXED_SETUP_TOKEN env var"
				class="w-full bg-surface border border-border rounded px-4 py-3 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
			/>

			<label class="block mb-2 mt-4 text-xs font-mono text-text-dim uppercase tracking-widest" for="org-name">
				Organization Name
			</label>
			<input
				id="org-name"
				type="text"
				bind:value={orgName}
				placeholder="My Team"
				class="w-full bg-surface border border-border rounded px-4 py-3 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
			/>

			<label class="block mb-2 mt-4 text-xs font-mono text-text-dim uppercase tracking-widest" for="setup-email">
				Admin Email
			</label>
			<input
				id="setup-email"
				type="email"
				bind:value={email}
				placeholder="admin@example.com"
				autocomplete="email"
				class="w-full bg-surface border border-border rounded px-4 py-3 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
			/>

			<label class="block mb-2 mt-4 text-xs font-mono text-text-dim uppercase tracking-widest" for="setup-password">
				Password
			</label>
			<input
				id="setup-password"
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
				disabled={loading || !setupToken.trim() || !email.trim() || !password}
				class="w-full mt-4 bg-phosphor text-base font-mono font-bold py-3 rounded text-sm uppercase tracking-wider hover:brightness-110 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
			>
				{loading ? 'Setting up...' : 'Create admin account'}
			</button>
		</form>
	</div>
</div>
