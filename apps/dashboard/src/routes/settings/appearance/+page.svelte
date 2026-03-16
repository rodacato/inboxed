<script lang="ts">
	import { getTheme } from '$lib/theme.svelte';
	import { toastStore } from '$lib/stores/toast.store.svelte';

	const theme = getTheme();

	let notificationsEnabled = $state(toastStore.enabled);

	function toggleNotifications() {
		notificationsEnabled = !notificationsEnabled;
		toastStore.setEnabled(notificationsEnabled);
	}
</script>

<div class="max-w-xl mx-auto p-6">
	<h1 class="text-xl font-display font-bold text-text-primary mb-6">Appearance</h1>

	<div class="bg-surface border border-border rounded-lg p-6 space-y-6">
		<!-- Theme -->
		<div>
			<label class="block mb-3 text-xs font-mono text-text-dim uppercase tracking-widest">
				Theme
			</label>
			<div class="flex gap-3">
				<button
					onclick={() => { if (theme.isDark) theme.toggle(); }}
					class="flex items-center gap-2.5 px-4 py-3 rounded-lg border text-sm font-mono transition-colors
						{!theme.isDark
						? 'border-phosphor bg-phosphor-glow text-phosphor'
						: 'border-border bg-surface-2 text-text-secondary hover:text-text-primary hover:border-text-dim'}"
				>
					<span class="material-symbols-outlined text-lg">light_mode</span>
					Light
				</button>
				<button
					onclick={() => { if (!theme.isDark) theme.toggle(); }}
					class="flex items-center gap-2.5 px-4 py-3 rounded-lg border text-sm font-mono transition-colors
						{theme.isDark
						? 'border-phosphor bg-phosphor-glow text-phosphor'
						: 'border-border bg-surface-2 text-text-secondary hover:text-text-primary hover:border-text-dim'}"
				>
					<span class="material-symbols-outlined text-lg">dark_mode</span>
					Dark
				</button>
			</div>
		</div>

		<!-- Notifications -->
		<div class="pt-6 border-t border-border">
			<label class="block mb-3 text-xs font-mono text-text-dim uppercase tracking-widest">
				Notifications
			</label>
			<button
				onclick={toggleNotifications}
				class="flex items-center gap-3 px-4 py-3 rounded-lg border text-sm font-mono transition-colors
					{notificationsEnabled
					? 'border-phosphor bg-phosphor-glow text-phosphor'
					: 'border-border bg-surface-2 text-text-secondary hover:text-text-primary hover:border-text-dim'}"
			>
				<span class="material-symbols-outlined text-lg">
					{notificationsEnabled ? 'notifications' : 'notifications_off'}
				</span>
				{notificationsEnabled ? 'Enabled' : 'Disabled'}
			</button>
			<p class="text-[10px] font-mono text-text-dim mt-2">
				Toast notifications for new emails and events.
			</p>
		</div>
	</div>
</div>
