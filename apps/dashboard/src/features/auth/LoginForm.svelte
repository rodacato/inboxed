<script lang="ts">
	import { authenticate } from './auth.service';

	let token = $state('');
	let error = $state('');
	let loading = $state(false);

	async function handleLogin() {
		if (!token.trim()) return;
		loading = true;
		error = '';

		try {
			await authenticate(token);
			window.location.href = '/projects';
		} catch {
			error = 'Invalid admin token';
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
			<p class="text-text-secondary text-sm mt-2 font-mono">Your emails go nowhere. You see everything.</p>
		</div>

		<form onsubmit={e => { e.preventDefault(); handleLogin(); }}>
			<label class="block mb-2 text-xs font-mono text-text-dim uppercase tracking-widest" for="token">
				Admin Token
			</label>
			<input
				id="token"
				type="password"
				bind:value={token}
				placeholder="Enter admin token..."
				class="w-full bg-surface border border-border rounded px-4 py-3 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
			/>

			{#if error}
				<p class="text-error text-xs font-mono mt-2">{error}</p>
			{/if}

			<button
				type="submit"
				disabled={loading || !token.trim()}
				class="w-full mt-4 bg-phosphor text-base font-mono font-bold py-3 rounded text-sm uppercase tracking-wider hover:brightness-110 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
			>
				{loading ? 'Authenticating...' : 'Authenticate'}
			</button>
		</form>
	</div>
</div>
