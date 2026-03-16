<script lang="ts">
	const githubUrl = 'https://github.com/rodacato/inboxed';
</script>

<svelte:head>
	<title>Privacy Policy — Inboxed</title>
	<meta name="description" content="Inboxed privacy policy. How we handle your data in the cloud trial and self-hosted deployments." />
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
		<h1 class="font-display text-3xl md:text-4xl font-bold mb-2">Privacy Policy</h1>
		<p class="font-mono text-text-dim text-sm mb-12">Last updated: March 16, 2026</p>

		<div class="font-body text-text-secondary leading-relaxed space-y-8">

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">TL;DR</h2>
				<div class="bg-surface rounded-xl border border-border p-6 font-mono text-sm space-y-2">
					<div><span class="text-phosphor">&#10003;</span> Self-hosted = your data, your server. We see nothing.</div>
					<div><span class="text-phosphor">&#10003;</span> Cloud trial = minimal data, auto-deleted after 1 hour.</div>
					<div><span class="text-phosphor">&#10003;</span> No analytics. No tracking. No ad networks.</div>
					<div><span class="text-phosphor">&#10003;</span> No telemetry in the self-hosted version.</div>
					<div><span class="text-phosphor">&#10003;</span> We don't sell data. Ever.</div>
				</div>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">1. Who we are</h2>
				<p>
					Inboxed is an open-source project maintained by <a href="https://notdefined.dev" class="text-cyan hover:underline">notdefined.dev</a>.
					When we say "we", "us", or "our" in this policy, we mean the Inboxed project maintainers.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">2. Self-hosted instances</h2>
				<p>
					If you self-host Inboxed, <strong class="text-text-primary">we have zero access to your data</strong>.
					The software runs entirely on your infrastructure. There is no telemetry, no phone-home,
					no analytics, and no external API calls made by the application.
				</p>
				<p class="mt-4">
					Your self-hosted instance stores emails, webhook payloads, and user accounts in your own PostgreSQL database.
					You are the data controller and processor. This privacy policy does not apply to self-hosted instances &mdash;
					your own privacy policy governs that data.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">3. Cloud trial (inboxed.notdefined.dev)</h2>
				<p>When you use the free cloud trial, we collect and process the following:</p>

				<h3 class="font-display text-lg font-semibold text-text-primary mt-6 mb-3">Data we collect</h3>
				<div class="overflow-x-auto">
					<table class="w-full font-body text-sm border-collapse">
						<thead>
							<tr class="border-b border-border">
								<th class="text-left py-3 px-4 font-display font-semibold text-text-primary">Data</th>
								<th class="text-left py-3 px-4 font-display font-semibold text-text-primary">Purpose</th>
								<th class="text-left py-3 px-4 font-display font-semibold text-text-primary">Retention</th>
							</tr>
						</thead>
						<tbody class="text-text-secondary">
							<tr class="border-b border-border/50"><td class="py-3 px-4">Email address</td><td class="py-3 px-4">Account creation and authentication</td><td class="py-3 px-4">Until account deletion</td></tr>
							<tr class="border-b border-border/50"><td class="py-3 px-4">Password (hashed)</td><td class="py-3 px-4">Authentication</td><td class="py-3 px-4">Until account deletion</td></tr>
							<tr class="border-b border-border/50"><td class="py-3 px-4">Test emails received</td><td class="py-3 px-4">Core service functionality</td><td class="py-3 px-4 font-mono text-amber">1 hour (auto-purged)</td></tr>
							<tr class="border-b border-border/50"><td class="py-3 px-4">Webhook payloads</td><td class="py-3 px-4">Core service functionality</td><td class="py-3 px-4 font-mono text-amber">1 hour (auto-purged)</td></tr>
							<tr><td class="py-3 px-4">GitHub OAuth profile (if used)</td><td class="py-3 px-4">Authentication</td><td class="py-3 px-4">Until account deletion</td></tr>
						</tbody>
					</table>
				</div>

				<h3 class="font-display text-lg font-semibold text-text-primary mt-6 mb-3">Data we do NOT collect</h3>
				<ul class="list-none space-y-2">
					<li><span class="text-phosphor font-mono mr-2">&times;</span> Analytics or usage tracking</li>
					<li><span class="text-phosphor font-mono mr-2">&times;</span> Cookies for advertising</li>
					<li><span class="text-phosphor font-mono mr-2">&times;</span> IP address logging (beyond standard server logs)</li>
					<li><span class="text-phosphor font-mono mr-2">&times;</span> Browser fingerprinting</li>
					<li><span class="text-phosphor font-mono mr-2">&times;</span> Third-party tracking scripts</li>
				</ul>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">4. Data processing</h2>
				<p>
					Test emails and webhook payloads sent to the cloud trial are stored temporarily to provide the service.
					They are automatically purged after 1 hour. We do not read, analyze, or mine the content of your test data.
				</p>
				<p class="mt-4">
					HTML email content is <strong class="text-text-primary">not rendered</strong> in the cloud trial.
					Only text content and headers are displayed, eliminating the risk of cross-tenant XSS.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">5. Data sharing</h2>
				<p>
					We do not sell, rent, or share your data with third parties. We do not use your data for advertising.
					The only scenario where we may disclose data is if legally compelled to do so by a valid court order.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">6. Infrastructure</h2>
				<p>
					The cloud trial runs on Hetzner Cloud (Germany/Finland, EU). Data is stored in the EU.
					Hetzner is GDPR-compliant and ISO 27001 certified.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">7. Your rights</h2>
				<ul class="list-none space-y-2">
					<li><span class="text-cyan font-mono mr-2">&rarr;</span> <strong class="text-text-primary">Delete your account</strong> at any time from the dashboard</li>
					<li><span class="text-cyan font-mono mr-2">&rarr;</span> <strong class="text-text-primary">Export your data</strong> via the REST API before deletion</li>
					<li><span class="text-cyan font-mono mr-2">&rarr;</span> <strong class="text-text-primary">Request data deletion</strong> by contacting us</li>
					<li><span class="text-cyan font-mono mr-2">&rarr;</span> <strong class="text-text-primary">Self-host</strong> for full data sovereignty</li>
				</ul>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">8. Cookies</h2>
				<p>
					The cloud trial uses a single session cookie for authentication. No tracking cookies,
					no third-party cookies, no cookie consent banner needed.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">9. Changes to this policy</h2>
				<p>
					We'll update this page if anything changes. Significant changes will be announced
					in the GitHub repository.
				</p>
			</section>

			<section>
				<h2 class="font-display text-xl font-semibold text-text-primary mb-4">10. Contact</h2>
				<p>
					Questions? Open an issue on
					<a href="{githubUrl}/issues" class="text-cyan hover:underline">GitHub</a>
					or email <span class="font-mono text-text-primary">privacy@notdefined.dev</span>.
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
				<span class="text-text-primary">Privacy</span>
				<a href="/terms" class="hover:text-text-primary transition-colors">Terms</a>
				<a href="{githubUrl}" class="hover:text-text-primary transition-colors">GitHub</a>
			</div>
		</div>
	</footer>
</div>
