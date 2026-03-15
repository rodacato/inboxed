<script lang="ts">
	let otpCopied = $state(false);

	function copyOtp() {
		navigator.clipboard.writeText('8829-X');
		otpCopied = true;
		setTimeout(() => (otpCopied = false), 2000);
	}
</script>

<section class="flex-1 flex flex-col bg-surface overflow-hidden">
	<!-- Toolbar -->
	<div class="h-14 px-6 border-b border-border flex items-center justify-between bg-base">
		<div class="flex gap-2">
			<button class="p-2 rounded-lg text-text-secondary hover:text-phosphor hover:bg-surface-2 transition-colors">
				<span class="material-symbols-outlined text-xl">archive</span>
			</button>
			<button class="p-2 rounded-lg text-text-secondary hover:text-amber hover:bg-surface-2 transition-colors">
				<span class="material-symbols-outlined text-xl">report</span>
			</button>
			<button class="p-2 rounded-lg text-text-secondary hover:text-error hover:bg-surface-2 transition-colors">
				<span class="material-symbols-outlined text-xl">delete</span>
			</button>
		</div>
		<div class="flex items-center gap-2">
			<button class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-mono text-phosphor border border-phosphor/20 hover:bg-phosphor-glow transition-colors">
				<span class="material-symbols-outlined text-sm">reply</span>
				reply
			</button>
			<button class="p-2 rounded-lg text-text-secondary hover:bg-surface-2 transition-colors">
				<span class="material-symbols-outlined">more_vert</span>
			</button>
		</div>
	</div>

	<!-- Email Content -->
	<div class="flex-1 overflow-y-auto p-8">
		<div class="max-w-3xl mx-auto space-y-6">
			<!-- Metadata -->
			<div class="p-6 rounded-lg bg-base border border-border">
				<h2 class="text-xl font-display font-bold text-text-primary mb-4">
					Your verification code: 8829-X
				</h2>
				<div class="flex items-center gap-4">
					<div class="size-10 rounded-full bg-cyan/20 flex items-center justify-center text-cyan font-mono font-bold text-sm">
						AS
					</div>
					<div class="flex-1 min-w-0">
						<div class="flex items-baseline gap-2">
							<span class="font-semibold text-sm text-text-primary">Auth Service</span>
							<span class="text-[11px] font-mono text-text-dim">&lt;auth-service@cloud.io&gt;</span>
						</div>
						<div class="text-[11px] text-text-dim font-mono">
							to signup@mail.inboxed.dev
						</div>
					</div>
					<div class="text-right">
						<p class="text-[11px] text-text-dim font-mono">2m ago</p>
					</div>
				</div>
			</div>

			<!-- Email Body -->
			<div class="rounded-lg overflow-hidden border border-border bg-base">
				<div class="bg-surface-2 px-4 py-2 border-b border-border flex items-center justify-between">
					<span class="text-[10px] font-mono text-text-dim uppercase tracking-widest">Sandboxed Preview</span>
					<div class="flex gap-1.5">
						<div class="size-2 rounded-full bg-text-dim"></div>
						<div class="size-2 rounded-full bg-text-dim"></div>
						<div class="size-2 rounded-full bg-text-dim"></div>
					</div>
				</div>
				<div class="p-8 text-text-primary leading-relaxed font-body">
					<p class="mb-4">Hello,</p>
					<p class="mb-6">
						Use the following code to verify your account. This code will expire in
						<strong class="text-amber">10 minutes</strong>.
					</p>

					<!-- OTP Code Block -->
					<div class="my-8 p-6 bg-surface rounded-lg border border-phosphor/20 text-center">
						<p class="text-[10px] font-mono text-text-dim uppercase tracking-widest mb-3">
							Verification Code
						</p>
						<p class="text-4xl font-mono font-bold text-phosphor tracking-[0.3em] terminal-glow">
							8829-X
						</p>
					</div>

					<!-- Copy OTP Button -->
					<div class="flex justify-center">
						<button
							onclick={copyOtp}
							class="font-mono text-sm px-6 py-2.5 rounded-lg border transition-all
								{otpCopied
								? 'bg-phosphor/20 border-phosphor/40 text-phosphor'
								: 'border-phosphor/20 text-phosphor/70 hover:text-phosphor hover:bg-phosphor-glow'}"
						>
							{otpCopied ? '[ copied ]' : '[ copy otp code ]'}
						</button>
					</div>

					<p class="mt-8 text-sm text-text-secondary">
						If you didn't request this code, you can safely ignore this email.
					</p>

					<div class="mt-10 pt-6 border-t border-border text-[10px] text-text-dim uppercase tracking-wider font-mono">
						Auth Service &bull; cloud.io &bull; Do not reply to this email
					</div>
				</div>
			</div>

			<!-- Raw Headers Toggle -->
			<details class="rounded-lg border border-border bg-base">
				<summary class="px-4 py-3 cursor-pointer text-[11px] font-mono text-text-dim uppercase tracking-widest hover:text-text-secondary transition-colors">
					Raw Headers
				</summary>
				<div class="px-4 pb-4 font-mono text-[11px] text-text-dim space-y-1 border-t border-border pt-3">
					<p><span class="text-text-secondary">From:</span> auth-service@cloud.io</p>
					<p><span class="text-text-secondary">To:</span> signup@mail.inboxed.dev</p>
					<p><span class="text-text-secondary">Subject:</span> Your verification code: 8829-X</p>
					<p><span class="text-text-secondary">Date:</span> {new Date().toUTCString()}</p>
					<p><span class="text-text-secondary">Message-ID:</span> &lt;msg_a8f29c3k@cloud.io&gt;</p>
					<p><span class="text-text-secondary">Content-Type:</span> text/html; charset=UTF-8</p>
				</div>
			</details>
		</div>
	</div>
</section>
