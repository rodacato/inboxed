<script lang="ts">
	import {
		fetchBlockedAddresses,
		createBlockedAddress,
		deleteBlockedAddress
	} from '../../../../features/site-admin/site-admin.service';
	import type { BlockedAddress } from '../../../../features/site-admin/site-admin.types';

	let addresses = $state<BlockedAddress[]>([]);
	let loading = $state(true);
	let newAddress = $state('');
	let newReason = $state('');
	let error = $state('');
	let successMessage = $state('');
	let adding = $state(false);

	$effect(() => {
		loadAddresses();
	});

	async function loadAddresses() {
		loading = true;
		try {
			addresses = await fetchBlockedAddresses();
		} catch {
			error = 'Failed to load blocked addresses';
		} finally {
			loading = false;
		}
	}

	async function handleAdd() {
		if (!newAddress.trim()) return;
		adding = true;
		error = '';
		successMessage = '';

		try {
			const result = await createBlockedAddress(newAddress.trim(), newReason.trim() || undefined);
			addresses = [result.data, ...addresses];
			if (result.deleted_inboxes > 0) {
				successMessage = `Address blocked. ${result.deleted_inboxes} existing inbox${result.deleted_inboxes > 1 ? 'es' : ''} deleted.`;
			} else {
				successMessage = 'Address blocked successfully.';
			}
			newAddress = '';
			newReason = '';
		} catch (err: any) {
			const body = err?.body;
			error = body?.message || body?.detail || 'Failed to block address';
		} finally {
			adding = false;
		}
	}

	async function handleRemove(id: string) {
		if (!confirm('Remove this address from the blocklist?')) return;
		try {
			await deleteBlockedAddress(id);
			addresses = addresses.filter((a) => a.id !== id);
		} catch {
			error = 'Failed to remove address';
		}
	}
</script>

<div class="max-w-2xl mx-auto p-6">
	<h1 class="text-2xl font-display font-bold text-text-primary mb-2">Blocked Addresses</h1>
	<p class="text-sm text-text-secondary font-mono mb-6">
		Block email addresses from being used as inboxes. Use <code class="text-phosphor">*@domain.com</code> for wildcard patterns.
		Existing inboxes matching a blocked address will be deleted.
	</p>

	<!-- Add form -->
	<div class="bg-surface border border-border rounded-lg p-4 mb-6">
		<div class="flex gap-3 mb-3">
			<input
				type="text"
				bind:value={newAddress}
				placeholder="user@example.com or *@spam.com"
				class="flex-1 bg-base border border-border rounded px-3 py-2 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
			/>
			<button
				onclick={handleAdd}
				disabled={adding || !newAddress.trim()}
				class="px-4 py-2 bg-error/90 text-white font-mono text-sm font-bold rounded hover:bg-error transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
			>
				{adding ? 'Blocking...' : 'Block'}
			</button>
		</div>
		<input
			type="text"
			bind:value={newReason}
			placeholder="Reason (optional)"
			class="w-full bg-base border border-border rounded px-3 py-2 font-mono text-xs text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
		/>
	</div>

	{#if error}
		<div class="bg-error/10 border border-error/30 rounded-lg px-4 py-3 mb-4">
			<p class="text-error text-xs font-mono">{error}</p>
		</div>
	{/if}

	{#if successMessage}
		<div class="bg-phosphor/10 border border-phosphor/30 rounded-lg px-4 py-3 mb-4">
			<p class="text-phosphor text-xs font-mono">{successMessage}</p>
		</div>
	{/if}

	<!-- List -->
	{#if loading}
		<p class="text-text-dim font-mono text-sm">Loading...</p>
	{:else if addresses.length === 0}
		<div class="text-center py-12 text-text-dim">
			<span class="material-symbols-outlined text-3xl mb-2">shield</span>
			<p class="font-mono text-sm">No blocked addresses yet</p>
		</div>
	{:else}
		<div class="space-y-2">
			{#each addresses as addr (addr.id)}
				<div class="flex items-center justify-between px-4 py-3 rounded-lg bg-surface-2 border border-border group">
					<div class="flex-1 min-w-0">
						<p class="font-mono text-sm text-text-primary truncate">{addr.address}</p>
						{#if addr.reason}
							<p class="text-[10px] text-text-dim font-mono mt-0.5 truncate">{addr.reason}</p>
						{/if}
					</div>
					<div class="flex items-center gap-3 ml-4">
						<span class="text-[10px] text-text-dim font-mono">
							{new Date(addr.created_at).toLocaleDateString()}
						</span>
						<button
							onclick={() => handleRemove(addr.id)}
							class="opacity-0 group-hover:opacity-100 text-error hover:text-error/80 transition-all"
							title="Remove from blocklist"
						>
							<span class="material-symbols-outlined text-base">close</span>
						</button>
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>
