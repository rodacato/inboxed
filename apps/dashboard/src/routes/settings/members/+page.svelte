<script lang="ts">
	import { onMount } from 'svelte';
	import { apiClient, ApiError } from '$lib/api-client';
	import { authStore } from '$lib/stores/auth.store.svelte';

	interface Member {
		id: string;
		email: string;
		role: string;
		joined_at: string;
	}

	interface Invitation {
		id: string;
		email: string;
		role: string;
		expires_at: string;
		invite_url: string;
	}

	let members = $state<Member[]>([]);
	let invitations = $state<Invitation[]>([]);
	let inviteEmail = $state('');
	let inviteRole = $state('member');
	let inviteError = $state('');
	let inviteLoading = $state(false);
	let inviteSuccess = $state('');
	let copiedId = $state<string | null>(null);

	const isAdmin = $derived(authStore.isOrgAdmin);

	onMount(() => {
		loadMembers();
		loadInvitations();
	});

	async function loadMembers() {
		try {
			const res = (await apiClient('/admin/members')) as { members: Member[] };
			members = res.members;
		} catch {
			// ignore
		}
	}

	async function loadInvitations() {
		try {
			const res = (await apiClient('/admin/invitations')) as { invitations: Invitation[] };
			invitations = res.invitations;
		} catch {
			// ignore
		}
	}

	async function handleInvite() {
		if (!inviteEmail.trim()) return;
		inviteLoading = true;
		inviteError = '';
		inviteSuccess = '';

		try {
			const res = (await apiClient('/admin/invitations', {
				method: 'POST',
				body: JSON.stringify({ email: inviteEmail, role: inviteRole })
			})) as { invitation: Invitation };

			inviteSuccess = authStore.outboundSmtpConfigured
				? `Invitation sent to ${inviteEmail}`
				: `Invitation created. Share this link:`;

			if (!authStore.outboundSmtpConfigured && res.invitation?.invite_url) {
				inviteSuccess += ` ${res.invitation.invite_url}`;
			}

			inviteEmail = '';
			loadInvitations();
		} catch (err) {
			if (err instanceof ApiError) {
				const body = err.body as Record<string, unknown>;
				inviteError = (body?.detail as string) || (body?.error as string) || 'Failed to send invitation.';
			} else {
				inviteError = 'Failed to send invitation.';
			}
		} finally {
			inviteLoading = false;
		}
	}

	async function removeMember(id: string) {
		if (!confirm('Remove this member from the organization?')) return;
		try {
			await apiClient(`/admin/members/${id}`, { method: 'DELETE' });
			loadMembers();
		} catch {
			// ignore
		}
	}

	async function revokeInvitation(id: string) {
		try {
			await apiClient(`/admin/invitations/${id}`, { method: 'DELETE' });
			loadInvitations();
		} catch {
			// ignore
		}
	}

	async function copyInviteUrl(inv: Invitation) {
		try {
			await navigator.clipboard.writeText(inv.invite_url);
			copiedId = inv.id;
			setTimeout(() => { copiedId = null; }, 2000);
		} catch {
			// ignore
		}
	}

	function formatDate(iso: string): string {
		return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
	}
</script>

<div>
	<div class="max-w-3xl mx-auto p-6">
		<div class="flex items-center justify-between mb-6">
			<h1 class="text-xl font-display font-bold text-text-primary">Members</h1>
		</div>

		<!-- Invite form (admin only) -->
		{#if isAdmin}
			<div class="bg-surface border border-border rounded-lg p-4 mb-6">
				<form onsubmit={e => { e.preventDefault(); handleInvite(); }} class="flex gap-3 items-end">
					<div class="flex-1">
						<label class="block mb-1 text-xs font-mono text-text-dim uppercase tracking-widest" for="invite-email">
							Email
						</label>
						<input
							id="invite-email"
							type="email"
							bind:value={inviteEmail}
							placeholder="user@example.com"
							class="w-full bg-base border border-border rounded px-3 py-2 font-mono text-sm text-text-primary placeholder:text-text-dim focus:outline-none focus:border-phosphor focus:ring-1 focus:ring-phosphor/30"
						/>
					</div>
					<div>
						<label class="block mb-1 text-xs font-mono text-text-dim uppercase tracking-widest" for="invite-role">
							Role
						</label>
						<select
							id="invite-role"
							bind:value={inviteRole}
							class="bg-base border border-border rounded px-3 py-2 font-mono text-sm text-text-primary focus:outline-none focus:border-phosphor"
						>
							<option value="member">Member</option>
							<option value="org_admin">Admin</option>
						</select>
					</div>
					<button
						type="submit"
						disabled={inviteLoading || !inviteEmail.trim()}
						class="bg-phosphor text-base font-mono font-bold px-4 py-2 rounded text-sm hover:brightness-110 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
					>
						{inviteLoading ? 'Inviting...' : 'Invite'}
					</button>
				</form>
				{#if inviteError}
					<p class="text-error text-xs font-mono mt-2">{inviteError}</p>
				{/if}
				{#if inviteSuccess}
					<p class="text-phosphor text-xs font-mono mt-2 break-all">{inviteSuccess}</p>
				{/if}
			</div>
		{/if}

		<!-- Members list -->
		<div class="bg-surface border border-border rounded-lg divide-y divide-border">
			{#each members as member (member.id)}
				<div class="flex items-center justify-between px-4 py-3">
					<div class="flex items-center gap-3 min-w-0">
						<span class="font-mono text-sm text-text-primary truncate">{member.email}</span>
						<span class="text-xs font-mono text-text-dim bg-surface-2 rounded px-2 py-0.5">{member.role}</span>
						{#if member.id === authStore.user?.id}
							<span class="text-xs font-mono text-phosphor">(you)</span>
						{/if}
					</div>
					<div class="flex items-center gap-3 shrink-0">
						<span class="text-xs font-mono text-text-dim">Joined {formatDate(member.joined_at)}</span>
						{#if isAdmin && member.id !== authStore.user?.id}
							<button
								onclick={() => removeMember(member.id)}
								class="text-xs font-mono text-error hover:underline"
							>
								Remove
							</button>
						{/if}
					</div>
				</div>
			{:else}
				<p class="px-4 py-6 text-sm font-mono text-text-dim text-center">No members</p>
			{/each}
		</div>

		<!-- Pending invitations -->
		{#if invitations.length > 0}
			<h2 class="text-sm font-display font-bold text-text-primary mt-8 mb-3">Pending invitations</h2>
			<div class="bg-surface border border-border rounded-lg divide-y divide-border">
				{#each invitations as inv (inv.id)}
					<div class="flex items-center justify-between px-4 py-3">
						<div class="flex items-center gap-3 min-w-0">
							<span class="font-mono text-sm text-text-primary truncate">{inv.email}</span>
							<span class="text-xs font-mono text-text-dim bg-surface-2 rounded px-2 py-0.5">{inv.role}</span>
						</div>
						<div class="flex items-center gap-3 shrink-0">
							<span class="text-xs font-mono text-text-dim">Expires {formatDate(inv.expires_at)}</span>
							<button
								onclick={() => copyInviteUrl(inv)}
								class="text-xs font-mono text-text-secondary hover:text-phosphor"
								title="Copy invite link"
							>
								{copiedId === inv.id ? 'Copied!' : 'Copy link'}
							</button>
							{#if isAdmin}
								<button
									onclick={() => revokeInvitation(inv.id)}
									class="text-xs font-mono text-error hover:underline"
								>
									Revoke
								</button>
							{/if}
						</div>
					</div>
				{/each}
			</div>
		{/if}

		<!-- SMTP notice -->
		{#if isAdmin && !authStore.outboundSmtpConfigured}
			<div class="mt-6 bg-surface border border-amber/30 rounded-lg p-4">
				<p class="text-xs font-mono text-amber">
					<span class="material-symbols-outlined text-sm align-text-bottom mr-1">warning</span>
					Outbound SMTP is not configured. Invitation emails will not be sent. Share the invite link manually.
				</p>
			</div>
		{/if}
	</div>
</div>
