<script lang="ts">
	const githubUrl = 'https://github.com/notdefined-dev/inboxed';
</script>

<svelte:head>
	<title>Terms of Service — Inboxed</title>
	<meta name="description" content="Inboxed terms of service for the cloud trial at cloud.inboxed.dev." />
</svelte:head>

<div class="min-h-screen bg-base text-text-primary antialiased">
	<!-- Navigation -->
	<nav class="fixed top-0 left-0 right-0 z-50 bg-base/80 backdrop-blur-lg border-b border-border/50">
		<div class="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
			<a href="/" class="flex items-center gap-2">
				<div class="size-7 bg-phosphor rounded-md flex items-center justify-center">
					<span class="material-symbols-outlined text-white dark:text-black" style="font-size: 18px;">alternate_email</span>
				</div>
				<span class="font-display text-xl font-bold">inboxed</span>
			</a>
			<a href="/" class="font-body text-sm text-text-secondary hover:text-text-primary transition-colors">
				&larr; Back to home
			</a>
		</div>
	</nav>

	<main class="max-w-3xl mx-auto px-6 pt-32 pb-24">
		<h1 class="font-display text-3xl md:text-4xl font-bold mb-2">Terms of Service</h1>
		<p class="font-mono text-text-dim text-sm mb-12">Last updated: March 16, 2026</p>

		<div class="font-body text-text-secondary leading-relaxed space-y-8">

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">TL;DR</h2>
				<div class="bg-surface rounded-xl border border-border p-6 font-mono text-sm space-y-2">
					<div><span class="text-phosphor">&#10003;</span> Use Inboxed for development and testing. Don't abuse it.</div>
					<div><span class="text-phosphor">&#10003;</span> Cloud trial is free with limits. Self-host for unlimited.</div>
					<div><span class="text-phosphor">&#10003;</span> Don't send spam, malware, or use it as an open relay.</div>
					<div><span class="text-phosphor">&#10003;</span> We can terminate accounts that violate these terms.</div>
					<div><span class="text-phosphor">&#10003;</span> The software is MIT-licensed. The cloud service has these additional terms.</div>
				</div>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">1. Scope</h2>
				<p>
					These terms apply to the <strong class="text-text-primary">Inboxed cloud trial</strong> at
					<span class="font-mono text-cyan">cloud.inboxed.dev</span>. The self-hosted open-source software is
					licensed under the <a href="{githubUrl}/blob/main/LICENSE" class="text-cyan hover:underline">MIT License</a>
					and is not subject to these terms.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">2. The service</h2>
				<p>
					Inboxed is a development and testing tool. The cloud trial provides:
				</p>
				<ul class="list-none space-y-2 mt-4">
					<li><span class="text-phosphor font-mono mr-2">&rarr;</span> SMTP email catching for test environments</li>
					<li><span class="text-phosphor font-mono mr-2">&rarr;</span> HTTP webhook catching</li>
					<li><span class="text-phosphor font-mono mr-2">&rarr;</span> REST API access</li>
					<li><span class="text-phosphor font-mono mr-2">&rarr;</span> Web dashboard for email/webhook inspection</li>
				</ul>
				<p class="mt-4">
					The cloud trial is provided <strong class="text-text-primary">as-is</strong>, free of charge, with
					<a href="/#pricing" class="text-cyan hover:underline">published limits</a>.
					We may modify limits, features, or availability at any time.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">3. Accounts</h2>
				<p>
					You need an account to use the cloud trial. You can register with email/password or GitHub OAuth.
					You are responsible for keeping your credentials secure. One account per person.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">4. Acceptable use</h2>
				<p>You agree <strong class="text-text-primary">not</strong> to:</p>
				<ul class="list-none space-y-2 mt-4">
					<li><span class="text-error font-mono mr-2">&times;</span> Use Inboxed as a relay to send spam or unsolicited email</li>
					<li><span class="text-error font-mono mr-2">&times;</span> Send malware, phishing content, or illegal material</li>
					<li><span class="text-error font-mono mr-2">&times;</span> Attempt to access other users' data</li>
					<li><span class="text-error font-mono mr-2">&times;</span> Overwhelm the service beyond rate limits</li>
					<li><span class="text-error font-mono mr-2">&times;</span> Use the service for production email delivery</li>
					<li><span class="text-error font-mono mr-2">&times;</span> Create multiple accounts to circumvent limits</li>
					<li><span class="text-error font-mono mr-2">&times;</span> Probe or scan for vulnerabilities without authorization</li>
				</ul>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">5. Data and retention</h2>
				<p>
					Test emails and webhook payloads are automatically deleted after <strong class="text-text-primary">1 hour</strong>.
					Account data (email, hashed password) is retained until you delete your account.
					See our <a href="/privacy" class="text-cyan hover:underline">Privacy Policy</a> for full details.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">6. Availability</h2>
				<p>
					The cloud trial is a free service. We make reasonable efforts to keep it available, but we do not
					guarantee uptime. For reliability guarantees, <a href="/#self-host" class="text-cyan hover:underline">self-host Inboxed</a>.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">7. Termination</h2>
				<p>
					We may suspend or terminate accounts that violate these terms. You can delete your account
					at any time from the dashboard. Upon deletion, all associated data is permanently removed.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">8. Limitation of liability</h2>
				<p>
					Inboxed is provided "as is" without warranty of any kind. We are not liable for any damages
					arising from the use of or inability to use the service. This is a <strong class="text-text-primary">testing tool</strong>.
					Do not rely on it for production workloads.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">9. Open source</h2>
				<p>
					The Inboxed software is open source under the
					<a href="{githubUrl}/blob/main/LICENSE" class="text-cyan hover:underline">MIT License</a>.
					These terms apply only to the hosted cloud trial, not to the software itself.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">10. Changes</h2>
				<p>
					We may update these terms. Changes will be posted here with an updated date.
					Continued use constitutes acceptance.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">11. Contact</h2>
				<p>
					Questions? Open an issue on
					<a href="{githubUrl}/issues" class="text-cyan hover:underline">GitHub</a>
					or email <span class="font-mono text-text-primary">legal@notdefined.dev</span>.
				</p>
			</section>
		</div>
	</main>

	<footer class="py-12 px-6 border-t border-border">
		<div class="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
			<div class="flex items-center gap-2">
				<div class="size-6 bg-phosphor rounded flex items-center justify-center">
					<span class="material-symbols-outlined text-white dark:text-black" style="font-size: 14px;">alternate_email</span>
				</div>
				<span class="font-display text-lg font-bold">inboxed</span>
			</div>
			<div class="flex items-center gap-6 font-body text-text-secondary text-sm">
				<a href="/privacy" class="hover:text-text-primary transition-colors">Privacy</a>
				<span class="text-text-primary">Terms</span>
				<a href="{githubUrl}" class="hover:text-text-primary transition-colors">GitHub</a>
			</div>
		</div>
	</footer>
</div>
