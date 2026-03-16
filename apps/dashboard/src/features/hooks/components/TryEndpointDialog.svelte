<script lang="ts">
	import { toastStore } from '$lib/stores/toast.store.svelte';
	import type { HttpEndpoint } from '../hooks.types';

	let {
		endpoint = $bindable<HttpEndpoint | null>(null)
	}: {
		endpoint: HttpEndpoint | null;
	} = $props();

	let body = $state('');
	let copied = $state(false);

	const defaults: Record<string, string> = {
		webhook: '{\n  "event": "test",\n  "data": {\n    "id": 1\n  }\n}',
		form: 'email=test@example.com&name=Test+User',
		heartbeat: ''
	};

	$effect(() => {
		if (endpoint) {
			body = defaults[endpoint.endpoint_type] ?? '';
			copied = false;
		}
	});

	const command = $derived(() => {
		if (!endpoint) return '';
		if (endpoint.endpoint_type === 'heartbeat') {
			return `curl -s ${endpoint.url}`;
		}
		if (endpoint.endpoint_type === 'form') {
			return `curl -X POST ${endpoint.url} \\\n  -d '${body}'`;
		}
		return `curl -X POST ${endpoint.url} \\\n  -H "Content-Type: application/json" \\\n  -d '${body}'`;
	});

	async function handleCopy() {
		await navigator.clipboard.writeText(command());
		copied = true;
		toastStore.add({ type: 'success', title: 'Copied to clipboard' });
		setTimeout(() => { copied = false; }, 2000);
	}

	function close() {
		endpoint = null;
	}
</script>

{#if endpoint}
	<div class="fixed inset-0 z-50 bg-black/50" role="presentation" onclick={close}></div>
	<div class="fixed inset-x-0 top-[12%] z-51 mx-auto w-full max-w-lg" role="dialog" aria-label="Try endpoint">
		<div class="bg-surface border border-border rounded-xl shadow-2xl overflow-hidden">
			<div class="px-6 py-4 border-b border-border">
				<div class="flex items-center gap-2">
					<span class="material-symbols-outlined text-lg text-phosphor">terminal</span>
					<h3 class="text-lg font-display font-bold text-text-primary">
						Try {endpoint.label || endpoint.endpoint_type}
					</h3>
				</div>
				<p class="text-xs font-mono text-text-dim mt-1">{endpoint.url}</p>
			</div>

			<div class="px-6 py-4 space-y-4">
				{#if endpoint.endpoint_type !== 'heartbeat'}
					<div>
						<label for="try-body" class="block text-xs font-mono text-text-dim uppercase mb-1">
							{endpoint.endpoint_type === 'form' ? 'Form data' : 'JSON body'}
						</label>
						<textarea
							id="try-body"
							bind:value={body}
							rows={endpoint.endpoint_type === 'form' ? 2 : 6}
							spellcheck="false"
							class="w-full bg-surface-2 border border-border rounded px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor resize-none"
						></textarea>
					</div>
				{/if}

				<div>
					<label class="block text-xs font-mono text-text-dim uppercase mb-1">Command</label>
					<pre class="bg-surface-2 border border-border rounded px-3 py-2 text-xs font-mono text-text-primary overflow-x-auto whitespace-pre-wrap">{command()}</pre>
				</div>
			</div>

			<div class="px-6 py-4 border-t border-border flex justify-end gap-3">
				<button
					type="button"
					onclick={close}
					class="px-4 py-2 text-sm font-mono text-text-secondary hover:text-text-primary"
				>
					Close
				</button>
				<button
					onclick={handleCopy}
					class="px-4 py-2 bg-phosphor text-base rounded text-sm font-mono font-medium hover:brightness-110 flex items-center gap-2"
				>
					<span class="material-symbols-outlined text-sm">{copied ? 'check' : 'content_copy'}</span>
					{copied ? 'Copied!' : 'Copy'}
				</button>
			</div>
		</div>
	</div>
{/if}
