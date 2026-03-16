<script lang="ts">
	import { updateEndpoint, deleteEndpoint } from '../hooks.service';
	import { toastStore } from '$lib/stores/toast.store.svelte';
	import type { HttpEndpoint } from '../hooks.types';

	let {
		projectId,
		endpoint = $bindable<HttpEndpoint | null>(null),
		onUpdate,
		onDelete
	}: {
		projectId: string;
		endpoint: HttpEndpoint | null;
		onUpdate?: (endpoint: HttpEndpoint) => void;
		onDelete?: (endpoint: HttpEndpoint) => void;
	} = $props();

	let label = $state('');
	let expectedInterval = $state(300);
	let responseMode = $state('json');
	let redirectUrl = $state('');
	let saving = $state(false);
	let error = $state('');

	const typeIcons: Record<string, string> = {
		webhook: 'webhook',
		form: 'description',
		heartbeat: 'favorite'
	};

	const typeLabels: Record<string, string> = {
		webhook: 'Webhook',
		form: 'Form',
		heartbeat: 'Heartbeat'
	};

	$effect(() => {
		if (endpoint) {
			label = endpoint.label ?? '';
			expectedInterval = endpoint.expected_interval_seconds ?? 300;
			responseMode = endpoint.response_mode ?? 'json';
			redirectUrl = endpoint.response_redirect_url ?? '';
		}
	});

	async function handleSave() {
		if (!endpoint) return;
		saving = true;
		error = '';
		try {
			const params: Record<string, unknown> = { label: label || null };
			if (endpoint.endpoint_type === 'heartbeat') {
				params.expected_interval_seconds = expectedInterval;
			}
			if (endpoint.endpoint_type === 'form') {
				params.response_mode = responseMode;
				params.response_redirect_url = responseMode === 'redirect' ? redirectUrl : null;
			}
			const res = await updateEndpoint(projectId, endpoint.token, params);
			onUpdate?.(res.endpoint);
			toastStore.add({ type: 'success', title: 'Endpoint updated' });
			endpoint = null;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to update';
			toastStore.add({ type: 'error', title: 'Update failed', description: error });
		} finally {
			saving = false;
		}
	}

	async function handleDelete() {
		if (!endpoint) return;
		if (!confirm(`Delete "${endpoint.label || endpoint.token}" and ALL its captured data?`)) return;
		try {
			await deleteEndpoint(projectId, endpoint.token);
			onDelete?.(endpoint);
			toastStore.add({ type: 'success', title: 'Endpoint deleted' });
			endpoint = null;
		} catch (e) {
			toastStore.add({ type: 'error', title: 'Delete failed' });
		}
	}

	function close() {
		if (saving) return;
		endpoint = null;
	}
</script>

{#if endpoint}
	<div class="fixed inset-0 z-50 bg-black/50" role="presentation" onclick={close}></div>
	<div class="fixed inset-x-0 top-[10%] z-51 mx-auto w-full max-w-lg" role="dialog" aria-label="Edit endpoint">
		<div class="bg-surface border border-border rounded-xl shadow-2xl overflow-hidden">
			<!-- Header -->
			<div class="px-6 py-4 border-b border-border flex items-center justify-between">
				<div class="flex items-center gap-2">
					<span class="material-symbols-outlined text-lg text-text-dim">{typeIcons[endpoint.endpoint_type] ?? 'link'}</span>
					<h3 class="text-lg font-display font-bold text-text-primary">{typeLabels[endpoint.endpoint_type] ?? 'Endpoint'} Settings</h3>
				</div>
				<button onclick={handleDelete} class="text-xs font-mono text-error hover:underline">Delete</button>
			</div>

			<form onsubmit={(e) => { e.preventDefault(); handleSave(); }} class="px-6 py-4 space-y-4">
				{#if error}
					<div class="text-xs font-mono text-error bg-error/10 border border-error/20 rounded px-3 py-2">{error}</div>
				{/if}

				<!-- Token + URL (read-only) -->
				<div>
					<label class="block text-xs font-mono text-text-dim uppercase mb-1">Token</label>
					<div class="flex items-center gap-2">
						<code class="flex-1 text-sm font-mono text-text-primary bg-surface-2 border border-border rounded px-3 py-2 select-all">{endpoint.token}</code>
						<button
							type="button"
							onclick={() => { navigator.clipboard.writeText(endpoint!.token); toastStore.add({ type: 'success', title: 'Token copied' }); }}
							class="px-2 py-2 text-text-dim hover:text-text-primary transition-colors"
							title="Copy token"
						>
							<span class="material-symbols-outlined text-sm">content_copy</span>
						</button>
					</div>
				</div>

				<div>
					<label class="block text-xs font-mono text-text-dim uppercase mb-1">URL</label>
					<div class="flex items-center gap-2">
						<code class="flex-1 text-xs font-mono text-text-secondary bg-surface-2 border border-border rounded px-3 py-2 select-all truncate">{endpoint.url}</code>
						<button
							type="button"
							onclick={() => { navigator.clipboard.writeText(endpoint!.url); toastStore.add({ type: 'success', title: 'URL copied' }); }}
							class="px-2 py-2 text-text-dim hover:text-text-primary transition-colors"
							title="Copy URL"
						>
							<span class="material-symbols-outlined text-sm">content_copy</span>
						</button>
					</div>
				</div>

				<!-- Usage snippet -->
				<div>
					<label class="block text-xs font-mono text-text-dim uppercase mb-1">Usage</label>
					{#if endpoint.endpoint_type === 'webhook'}
						<pre class="text-xs font-mono text-text-primary bg-surface-2 border border-border rounded px-3 py-2 overflow-x-auto">curl -X POST {endpoint.url} \
  -H "Content-Type: application/json" \
  -d '{JSON.stringify({ event: "test" })}'</pre>
					{:else if endpoint.endpoint_type === 'form'}
						<pre class="text-xs font-mono text-text-primary bg-surface-2 border border-border rounded px-3 py-2 overflow-x-auto">&lt;form action="{endpoint.url}" method="POST"&gt;
  &lt;input name="email" /&gt;
  &lt;button type="submit"&gt;Send&lt;/button&gt;
&lt;/form&gt;</pre>
					{:else if endpoint.endpoint_type === 'heartbeat'}
						<pre class="text-xs font-mono text-text-primary bg-surface-2 border border-border rounded px-3 py-2 overflow-x-auto"># In your crontab:
*/5 * * * * curl -s {endpoint.url}</pre>
					{/if}
				</div>

				<!-- Label -->
				<div>
					<label for="edit-ep-label" class="block text-xs font-mono text-text-dim uppercase mb-1">Label</label>
					<input
						id="edit-ep-label"
						type="text"
						bind:value={label}
						placeholder="e.g. Stripe webhooks"
						class="w-full bg-surface-2 border border-border rounded px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor"
					/>
				</div>

				{#if endpoint.endpoint_type === 'heartbeat'}
					<div>
						<label for="edit-ep-interval" class="block text-xs font-mono text-text-dim uppercase mb-1">Expected interval (seconds)</label>
						<input
							id="edit-ep-interval"
							type="number"
							bind:value={expectedInterval}
							min="10"
							class="w-full bg-surface-2 border border-border rounded px-3 py-2 text-sm font-mono text-text-primary focus:outline-none focus:border-phosphor"
						/>
					</div>
				{/if}

				{#if endpoint.endpoint_type === 'form'}
					<div>
						<label for="edit-ep-response-mode" class="block text-xs font-mono text-text-dim uppercase mb-1">Response mode</label>
						<select
							id="edit-ep-response-mode"
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
							<label for="edit-ep-redirect" class="block text-xs font-mono text-text-dim uppercase mb-1">Redirect URL</label>
							<input
								id="edit-ep-redirect"
								type="url"
								bind:value={redirectUrl}
								placeholder="https://myapp.test/thanks"
								class="w-full bg-surface-2 border border-border rounded px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor"
							/>
						</div>
					{/if}
				{/if}

				<!-- Actions -->
				<div class="flex justify-end gap-3 pt-2">
					<button
						type="button"
						onclick={close}
						class="px-4 py-2 text-sm font-mono text-text-secondary hover:text-text-primary"
					>
						Cancel
					</button>
					<button
						type="submit"
						disabled={saving}
						class="px-4 py-2 bg-phosphor text-base rounded text-sm font-mono font-medium hover:brightness-110 disabled:opacity-50"
					>
						{saving ? 'Saving...' : 'Save'}
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}
