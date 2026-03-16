<script lang="ts">
	import { createEndpoint } from '../hooks.service';
	import { toastStore } from '$lib/stores/toast.store.svelte';
	import type { HttpEndpoint, CreateEndpointParams } from '../hooks.types';

	let {
		projectId,
		open = $bindable(false),
		onCreate
	}: {
		projectId: string;
		open: boolean;
		onCreate?: (endpoint: HttpEndpoint) => void;
	} = $props();

	let endpointType = $state<'webhook' | 'form' | 'heartbeat'>('webhook');
	let label = $state('');
	let expectedInterval = $state(300);
	let responseMode = $state('json');
	let redirectUrl = $state('');
	let creating = $state(false);
	let error = $state('');

	const typeOptions = [
		{ value: 'webhook' as const, label: 'Webhook', icon: 'webhook', desc: 'Catch HTTP requests' },
		{ value: 'form' as const, label: 'Form', icon: 'description', desc: 'Capture form submissions' },
		{ value: 'heartbeat' as const, label: 'Heartbeat', icon: 'favorite', desc: 'Monitor cron jobs' }
	];

	function reset() {
		endpointType = 'webhook';
		label = '';
		expectedInterval = 300;
		responseMode = 'json';
		redirectUrl = '';
		creating = false;
		error = '';
	}

	async function handleSubmit() {
		creating = true;
		error = '';
		try {
			const params: CreateEndpointParams = {
				endpoint_type: endpointType,
				label: label || undefined
			};
			if (endpointType === 'heartbeat') {
				params.expected_interval_seconds = expectedInterval;
			}
			if (endpointType === 'form') {
				params.response_mode = responseMode;
				if (responseMode === 'redirect') {
					params.response_redirect_url = redirectUrl;
				}
			}
			const res = await createEndpoint(projectId, params);
			onCreate?.(res.endpoint);
			open = false;
			reset();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to create endpoint';
			toastStore.add({ type: 'error', title: 'Creation failed', description: error });
		} finally {
			creating = false;
		}
	}

	function close() {
		if (creating) return;
		open = false;
		reset();
	}
</script>

{#if open}
	<div class="fixed inset-0 z-50 bg-black/50" role="presentation" onclick={close}></div>
	<div
		class="fixed inset-x-0 top-[15%] z-51 mx-auto w-full max-w-md"
		role="dialog"
		aria-label="Create endpoint"
	>
		<form
			onsubmit={(e) => {
				e.preventDefault();
				handleSubmit();
			}}
			class="bg-surface border border-border rounded-xl shadow-2xl overflow-hidden"
		>
			<div class="px-6 py-4 border-b border-border">
				<h3 class="text-lg font-display font-bold text-text-primary">Create Endpoint</h3>
			</div>

			<div class="px-6 py-4 space-y-4">
				{#if error}
					<div class="text-xs font-mono text-error bg-error/10 border border-error/20 rounded px-3 py-2">{error}</div>
				{/if}

				<!-- Type selector -->
				<div>
					<!-- svelte-ignore a11y_label_has_associated_control -->
					<label class="block text-xs font-mono text-text-dim uppercase mb-2">Type</label>
					<div class="grid grid-cols-3 gap-2">
						{#each typeOptions as opt (opt.value)}
							<button
								type="button"
								onclick={() => (endpointType = opt.value)}
								class="p-3 rounded-lg border text-left transition-colors
									{endpointType === opt.value
									? 'border-phosphor bg-phosphor-glow'
									: 'border-border hover:bg-surface-2'}"
							>
								<span class="material-symbols-outlined text-lg block mb-1">{opt.icon}</span>
								<span class="text-sm font-mono font-medium text-text-primary block">{opt.label}</span>
								<span class="text-[10px] font-mono text-text-dim">{opt.desc}</span>
							</button>
						{/each}
					</div>
				</div>

				<div>
					<label for="ep-label" class="block text-xs font-mono text-text-dim uppercase mb-1">Label</label>
					<input
						id="ep-label"
						type="text"
						bind:value={label}
						placeholder="e.g. Stripe webhooks"
						class="w-full bg-surface-2 border border-border rounded px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor"
					/>
				</div>

				{#if endpointType === 'heartbeat'}
					<div>
						<label for="ep-interval" class="block text-xs font-mono text-text-dim uppercase mb-1">Expected interval (seconds)</label>
						<input
							id="ep-interval"
							type="number"
							bind:value={expectedInterval}
							min="10"
							class="w-full bg-surface-2 border border-border rounded px-3 py-2 text-sm font-mono text-text-primary focus:outline-none focus:border-phosphor"
						/>
					</div>
				{/if}

				{#if endpointType === 'form'}
					<div>
						<label for="ep-response-mode" class="block text-xs font-mono text-text-dim uppercase mb-1">Response mode</label>
						<select
							id="ep-response-mode"
							bind:value={responseMode}
							class="w-full bg-surface-2 border border-border rounded px-3 py-2 text-sm font-mono text-text-primary focus:outline-none focus:border-phosphor"
						>
							<option value="json">JSON response</option>
							<option value="redirect">Redirect</option>
							<option value="html">Thank you page</option>
						</select>
					</div>
					{#if responseMode === 'redirect'}
						<div>
							<label for="ep-redirect" class="block text-xs font-mono text-text-dim uppercase mb-1">Redirect URL</label>
							<input
								id="ep-redirect"
								type="url"
								bind:value={redirectUrl}
								placeholder="https://myapp.test/thanks"
								class="w-full bg-surface-2 border border-border rounded px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor"
							/>
						</div>
					{/if}
				{/if}
			</div>

			<div class="px-6 py-4 border-t border-border flex justify-end gap-3">
				<button
					type="button"
					onclick={close}
					class="px-4 py-2 text-sm font-mono text-text-secondary hover:text-text-primary"
				>
					Cancel
				</button>
				<button
					type="submit"
					disabled={creating}
					class="px-4 py-2 bg-phosphor text-base rounded text-sm font-mono font-medium hover:brightness-110 disabled:opacity-50"
				>
					{creating ? 'Creating...' : 'Create'}
				</button>
			</div>
		</form>
	</div>
{/if}
