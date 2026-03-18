<script lang="ts">
	import { onMount } from 'svelte';
	import { register, getErrorMessage } from '../../features/auth/auth.service';
	import { goto } from '$app/navigation';

	let email = $state('');
	let password = $state('');
	let error = $state('');
	let loading = $state(false);
	let verificationSent = $state(false);
	let turnstileToken = $state('');
	let turnstileSiteKey = $state('');
	let turnstileWidgetId = $state<string | null>(null);

	onMount(() => {
		// Load Turnstile site key from status endpoint
		fetch('/admin/status')
			.then((r) => r.json())
			.then((data) => {
				const key = data?.data?.turnstile_site_key || data?.turnstile_site_key;
				if (key) {
					turnstileSiteKey = key;
					loadTurnstileScript();
				}
			})
			.catch(() => {});
	});

	function loadTurnstileScript() {
		if (document.querySelector('script[src*="turnstile"]')) {
			renderWidget();
			return;
		}
		const script = document.createElement('script');
		script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTurnstileLoad&render=explicit';
		script.async = true;
		(window as Record<string, unknown>).onTurnstileLoad = () => renderWidget();
		document.head.appendChild(script);
	}

	function renderWidget() {
		const container = document.getElementById('turnstile-container');
		if (!container || !turnstileSiteKey) return;
		if (turnstileWidgetId !== null) return;

		turnstileWidgetId = (window as Record<string, Record<string, (...args: unknown[]) => unknown>>).turnstile.render('#turnstile-container', {
			sitekey: turnstileSiteKey,
			callback: (token: string) => { turnstileToken = token; },
			'expired-callback': () => { turnstileToken = ''; },
			theme: 'dark'
		});
	}

	async function handleRegister() {
		if (!email.trim() || !password) return;
		if (turnstileSiteKey && !turnstileToken) {
			error = 'Please complete the captcha.';
			return;
		}
		loading = true;
		error = '';

		try {
			const result = await register(email, password, undefined, turnstileToken || undefined);
			if (result.verificationRequired) {
				verificationSent = true;
			} else {
				goto('/login');
			}
		} catch (err) {
			error = getErrorMessage(err);
			// Reset turnstile on error
			if (turnstileWidgetId !== null && (window as Record<string, unknown>).turnstile) {
				((window as Record<string, Record<string, (...args: unknown[]) => unknown>>).turnstile).reset(turnstileWidgetId);
				turnstileToken = '';
			}
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
			<p class="text-text-secondary text-sm mt-2 font-mono">Create your account</p>
		</div>

		{#if verificationSent}
			<div class="bg-surface border border-border rounded-lg p-6 text-center">
				<span class="material-symbols-outlined text-phosphor text-3xl mb-3">mark_email_read</span>
				<h2 class="text-text-primary font-display font-bold text-lg mb-2">Check your email</h2>
				<p class="text-text-secondary text-sm font-mono">
					We sent a verification link to <strong class="text-text-primary">{email}</strong>. Click it to activate your account.
				</p>
				<a href="/login" class="inline-block mt-4 text-phosphor text-sm font-mono hover:underline">
					Back to login
				</a>
			</div>
		{:else}
			<form onsubmit={e => { e.preventDefault(); handleRegister(); }}>
				<label class="block mb-2 text-xs font-mono text-text-dim uppercase tracking-widest" for="reg-email">
					Email
				</label>
				<input
					id="reg-email"
					type="email"
					bind:value={email}
					placeholder="you@example.com"
					autocomplete="email"
					class="w-full bg-surface border border-border rounded px-4 py-3 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
				/>

				<label class="block mb-2 mt-4 text-xs font-mono text-text-dim uppercase tracking-widest" for="reg-password">
					Password
				</label>
				<input
					id="reg-password"
					type="password"
					bind:value={password}
					placeholder="Min. 8 characters"
					autocomplete="new-password"
					class="w-full bg-surface border border-border rounded px-4 py-3 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
				/>

				{#if turnstileSiteKey}
					<div id="turnstile-container" class="mt-4 flex justify-center"></div>
				{/if}

				{#if error}
					<p class="text-error text-xs font-mono mt-2">{error}</p>
				{/if}

				<button
					type="submit"
					disabled={loading || !email.trim() || !password || (!!turnstileSiteKey && !turnstileToken)}
					class="w-full mt-4 bg-phosphor text-base font-mono font-bold py-3 rounded text-sm uppercase tracking-wider hover:brightness-110 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
				>
					{loading ? 'Creating account...' : 'Register'}
				</button>
			</form>

			<p class="mt-6 text-center text-xs font-mono text-text-dim">
				Already have an account? <a href="/login" class="text-phosphor hover:underline">Sign in</a>
			</p>
		{/if}
	</div>
</div>
