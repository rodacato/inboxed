<script lang="ts">
	const githubUrl = 'https://github.com/rodacato/inboxed';

	let activeTab = $state<'local' | 'production'>('local');
</script>

<svelte:head>
	<title>Self-Host Guide — Inboxed</title>
	<meta name="description" content="Step-by-step guide to self-host Inboxed locally with Docker or in production with a VPS, Cloudflare Tunnel, and email routing." />
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

	<main class="max-w-4xl mx-auto px-6 pt-32 pb-24">
		<!-- Header -->
		<h1 class="font-display text-3xl md:text-5xl font-bold mb-4">Self-Host Guide</h1>
		<p class="text-text-secondary text-lg mb-12 max-w-2xl">
			Run Inboxed on your own infrastructure. Choose your scenario:
		</p>

		<!-- Tab selector -->
		<div class="flex gap-2 mb-12 p-1 bg-surface rounded-xl border border-border w-fit">
			<button
				onclick={() => activeTab = 'local'}
				class="px-6 py-3 rounded-lg text-sm font-display font-bold transition-all {activeTab === 'local' ? 'bg-phosphor text-white dark:text-black' : 'text-text-secondary hover:text-text-primary'}"
			>
				Local / Development
			</button>
			<button
				onclick={() => activeTab = 'production'}
				class="px-6 py-3 rounded-lg text-sm font-display font-bold transition-all {activeTab === 'production' ? 'bg-phosphor text-white dark:text-black' : 'text-text-secondary hover:text-text-primary'}"
			>
				Production / VPS
			</button>
		</div>

		<!-- ═══════════════════════════════════════════════════════ -->
		<!-- LOCAL / DEVELOPMENT TAB                                 -->
		<!-- ═══════════════════════════════════════════════════════ -->
		{#if activeTab === 'local'}
		<div class="space-y-16">
			<!-- Overview -->
			<section>
				<div class="bg-surface/50 border border-border rounded-2xl p-8">
					<h3 class="font-display text-lg font-bold mb-3 text-phosphor">What you get</h3>
					<p class="text-text-secondary text-sm leading-relaxed mb-4">
						A full Inboxed instance on your machine: SMTP server, REST API, dashboard, and MCP server.
						Point your app's SMTP config at <code class="font-mono text-phosphor">localhost</code> and every email gets caught.
					</p>
					<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6">
						<div class="text-center p-3 bg-base rounded-lg border border-border/50">
							<div class="font-mono text-xs text-phosphor mb-1">Dashboard</div>
							<div class="text-text-dim text-xs">:80</div>
						</div>
						<div class="text-center p-3 bg-base rounded-lg border border-border/50">
							<div class="font-mono text-xs text-phosphor mb-1">API</div>
							<div class="text-text-dim text-xs">:3100</div>
						</div>
						<div class="text-center p-3 bg-base rounded-lg border border-border/50">
							<div class="font-mono text-xs text-cyan mb-1">SMTP</div>
							<div class="text-text-dim text-xs">:587</div>
						</div>
						<div class="text-center p-3 bg-base rounded-lg border border-border/50">
							<div class="font-mono text-xs text-amber mb-1">MCP</div>
							<div class="text-text-dim text-xs">:3001</div>
						</div>
					</div>
				</div>
			</section>

			<!-- Prerequisites -->
			<section>
				<h2 class="font-display text-2xl font-bold mb-2">Prerequisites</h2>
				<div class="h-px bg-border mb-6"></div>
				<ul class="space-y-3 text-text-secondary text-sm">
					<li class="flex items-start gap-3">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div><strong class="text-text-primary">Docker</strong> &mdash; <a href="https://docs.docker.com/get-docker/" class="text-phosphor hover:underline" target="_blank" rel="noopener">Install Docker</a></div>
					</li>
					<li class="flex items-start gap-3">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div><strong class="text-text-primary">Docker Compose v2</strong> &mdash; included with Docker Desktop, or <a href="https://docs.docker.com/compose/install/" class="text-phosphor hover:underline" target="_blank" rel="noopener">install separately</a></div>
					</li>
					<li class="flex items-start gap-3">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div><strong class="text-text-primary">Git</strong> &mdash; to clone the repo</div>
					</li>
				</ul>
			</section>

			<!-- Step 1 -->
			<section>
				<div class="flex items-center gap-4 mb-6">
					<span class="flex items-center justify-center size-10 rounded-full bg-phosphor/10 text-phosphor font-mono font-bold text-lg">1</span>
					<h2 class="font-display text-2xl font-bold">Clone &amp; run setup</h2>
				</div>
				<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-sm space-y-2">
					<p class="text-text-secondary"><span class="text-phosphor">$</span> git clone {githubUrl} &amp;&amp; cd inboxed</p>
					<p class="text-text-secondary"><span class="text-phosphor">$</span> bin/setup</p>
				</div>
				<p class="text-text-secondary text-sm mt-4 leading-relaxed">
					The setup wizard will ask for your domain (default: <code class="font-mono text-phosphor">localhost</code>),
					dashboard port, and SMTP port. It auto-generates all secrets (<code class="font-mono text-text-dim">SECRET_KEY_BASE</code>,
					<code class="font-mono text-text-dim">POSTGRES_PASSWORD</code>, <code class="font-mono text-text-dim">INBOXED_SETUP_TOKEN</code>,
					<code class="font-mono text-text-dim">INBOXED_MCP_KEY</code>) and writes a <code class="font-mono text-phosphor">.env</code> file.
				</p>
			</section>

			<!-- Step 2 -->
			<section>
				<div class="flex items-center gap-4 mb-6">
					<span class="flex items-center justify-center size-10 rounded-full bg-phosphor/10 text-phosphor font-mono font-bold text-lg">2</span>
					<h2 class="font-display text-2xl font-bold">Start the services</h2>
				</div>
				<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-sm space-y-2">
					<p class="text-text-secondary"><span class="text-phosphor">$</span> docker compose up -d</p>
				</div>
				<p class="text-text-secondary text-sm mt-4 leading-relaxed">
					This builds and starts 5 containers: <strong class="text-text-primary">API</strong> (Rails),
					<strong class="text-text-primary">Dashboard</strong> (Svelte),
					<strong class="text-text-primary">MCP</strong> (Node.js),
					<strong class="text-text-primary">PostgreSQL</strong>, and
					<strong class="text-text-primary">Redis</strong>.
					First build takes a few minutes. Subsequent starts are instant.
				</p>
			</section>

			<!-- Step 3 -->
			<section>
				<div class="flex items-center gap-4 mb-6">
					<span class="flex items-center justify-center size-10 rounded-full bg-phosphor/10 text-phosphor font-mono font-bold text-lg">3</span>
					<h2 class="font-display text-2xl font-bold">Create admin account</h2>
				</div>
				<p class="text-text-secondary text-sm leading-relaxed mb-4">
					Open <code class="font-mono text-phosphor">http://localhost/setup</code> in your browser.
					Enter the setup token from your <code class="font-mono text-text-dim">.env</code> file and create your admin account.
				</p>
				<div class="bg-surface/50 border border-amber/20 rounded-xl p-4 flex items-start gap-3">
					<span class="text-amber text-lg mt-0.5">!</span>
					<p class="text-text-secondary text-sm">
						The setup token is printed at the end of <code class="font-mono text-phosphor">bin/setup</code> output.
						You can also find it in your <code class="font-mono text-text-dim">.env</code> as <code class="font-mono text-text-dim">INBOXED_SETUP_TOKEN</code>.
					</p>
				</div>
			</section>

			<!-- Step 4 -->
			<section>
				<div class="flex items-center gap-4 mb-6">
					<span class="flex items-center justify-center size-10 rounded-full bg-phosphor/10 text-phosphor font-mono font-bold text-lg">4</span>
					<h2 class="font-display text-2xl font-bold">Configure your app's SMTP</h2>
				</div>
				<p class="text-text-secondary text-sm leading-relaxed mb-4">
					Point your application's SMTP config at Inboxed. Any email your app sends will be caught and displayed in the dashboard.
				</p>
				<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-sm space-y-1">
					<p class="text-text-dim"># Your app's .env</p>
					<p class="text-text-secondary">SMTP_HOST=<span class="text-phosphor">localhost</span></p>
					<p class="text-text-secondary">SMTP_PORT=<span class="text-phosphor">587</span></p>
					<p class="text-text-secondary">SMTP_USERNAME=  <span class="text-text-dim"># leave empty</span></p>
					<p class="text-text-secondary">SMTP_PASSWORD=  <span class="text-text-dim"># leave empty</span></p>
				</div>
			</section>

			<!-- Step 5: MCP -->
			<section>
				<div class="flex items-center gap-4 mb-6">
					<span class="flex items-center justify-center size-10 rounded-full bg-cyan/10 text-cyan font-mono font-bold text-lg">5</span>
					<h2 class="font-display text-2xl font-bold">Connect MCP (optional)</h2>
				</div>
				<p class="text-text-secondary text-sm leading-relaxed mb-4">
					Add Inboxed to Claude Code, Cursor, or any MCP-compatible client. The MCP server runs as a Docker container
					that connects to your local API.
				</p>
				<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-xs">
<pre class="text-text-secondary whitespace-pre overflow-x-auto"><span class="text-text-dim">// claude_desktop_config.json or .mcp.json</span>
&#123;
  "mcpServers": &#123;
    "inboxed": &#123;
      "command": "docker",
      "args": [
        "run", "-i", "--rm", "--network", "host",
        "-e", "<span class="text-phosphor">INBOXED_API_URL=http://localhost:3100</span>",
        "-e", "<span class="text-phosphor">INBOXED_API_KEY=&lt;your-api-key&gt;</span>",
        "ghcr.io/rodacato/inboxed-mcp"
      ]
    &#125;
  &#125;
&#125;</pre>
				</div>
				<p class="text-text-secondary text-sm mt-4">
					Get your API key from <strong class="text-text-primary">Settings &rarr; Projects &rarr; API Key</strong> in the dashboard.
				</p>
			</section>

			<!-- Limitations -->
			<section>
				<h2 class="font-display text-2xl font-bold mb-2">Local limitations</h2>
				<div class="h-px bg-border mb-6"></div>
				<div class="space-y-4">
					<div class="flex items-start gap-3 text-text-secondary text-sm">
						<span class="text-amber mt-0.5">!</span>
						<div><strong class="text-text-primary">No inbound email from the internet</strong> &mdash; the SMTP server only catches emails sent from your local network. External senders can't reach it without port forwarding or a tunnel.</div>
					</div>
					<div class="flex items-start gap-3 text-text-secondary text-sm">
						<span class="text-amber mt-0.5">!</span>
						<div><strong class="text-text-primary">No TLS on SMTP</strong> &mdash; local mode runs SMTP without encryption. Fine for <code class="font-mono text-text-dim">localhost</code>, not for production.</div>
					</div>
					<div class="flex items-start gap-3 text-text-secondary text-sm">
						<span class="text-amber mt-0.5">!</span>
						<div><strong class="text-text-primary">HTTP only</strong> &mdash; dashboard and API run over plain HTTP. Use the production guide below for HTTPS.</div>
					</div>
					<div class="flex items-start gap-3 text-text-secondary text-sm">
						<span class="text-amber mt-0.5">!</span>
						<div><strong class="text-text-primary">No webhook endpoints from external services</strong> &mdash; HTTP hook URLs are <code class="font-mono text-text-dim">localhost</code>, unreachable from services like Stripe or GitHub. Use a tunnel (ngrok, Cloudflare Tunnel) or the production setup.</div>
					</div>
				</div>
			</section>

			<!-- .env.example -->
			<section>
				<h2 class="font-display text-2xl font-bold mb-2">Configuration reference</h2>
				<div class="h-px bg-border mb-6"></div>
				<p class="text-text-secondary text-sm leading-relaxed mb-4">
					The <code class="font-mono text-phosphor">.env.example</code> file documents every setting available: feature flags,
					rate limits, storage limits, SMTP tuning, and more. Review it to customize your instance.
				</p>
				<div class="bg-surface/50 border border-border rounded-2xl p-6">
					<h4 class="font-display font-bold text-sm mb-4">Key settings to know</h4>
					<div class="space-y-3 text-sm">
						<div class="flex items-start gap-3">
							<code class="font-mono text-xs text-cyan bg-cyan/10 px-2 py-0.5 rounded shrink-0">INBOXED_FEATURE_HOOKS</code>
							<span class="text-text-secondary">Enable/disable HTTP webhook catching. Default: <code class="font-mono text-phosphor">true</code>.</span>
						</div>
						<div class="flex items-start gap-3">
							<code class="font-mono text-xs text-cyan bg-cyan/10 px-2 py-0.5 rounded shrink-0">INBOXED_FEATURE_FORMS</code>
							<span class="text-text-secondary">Enable/disable HTML form endpoint catching. Default: <code class="font-mono text-phosphor">true</code>.</span>
						</div>
						<div class="flex items-start gap-3">
							<code class="font-mono text-xs text-cyan bg-cyan/10 px-2 py-0.5 rounded shrink-0">INBOXED_FEATURE_HEARTBEATS</code>
							<span class="text-text-secondary">Enable/disable heartbeat monitoring endpoints. Default: <code class="font-mono text-phosphor">true</code>.</span>
						</div>
						<div class="flex items-start gap-3">
							<code class="font-mono text-xs text-cyan bg-cyan/10 px-2 py-0.5 rounded shrink-0">INBOXED_FEATURE_INBOUND_EMAIL</code>
							<span class="text-text-secondary">Receive real emails from the internet (needs Cloudflare Worker or MX). Default: <code class="font-mono text-text-dim">false</code>.</span>
						</div>
						<div class="flex items-start gap-3">
							<code class="font-mono text-xs text-cyan bg-cyan/10 px-2 py-0.5 rounded shrink-0">EMAIL_TTL_HOURS</code>
							<span class="text-text-secondary">Auto-delete emails after N hours. Default: <code class="font-mono text-phosphor">168</code> (7 days). Set <code class="font-mono text-text-dim">0</code> to keep forever.</span>
						</div>
						<div class="flex items-start gap-3">
							<code class="font-mono text-xs text-cyan bg-cyan/10 px-2 py-0.5 rounded shrink-0">REGISTRATION_MODE</code>
							<span class="text-text-secondary"><code class="font-mono text-text-dim">open</code>, <code class="font-mono text-text-dim">invite_only</code>, or <code class="font-mono text-text-dim">closed</code>. Controls who can sign up.</span>
						</div>
					</div>
					<p class="text-text-dim text-xs mt-4 font-mono">
						See .env.example for the full list including rate limits, SMTP tuning, and infrastructure settings.
					</p>
				</div>
			</section>

			<!-- Dev Container -->
			<section>
				<h2 class="font-display text-2xl font-bold mb-2">Alternative: Dev Container</h2>
				<div class="h-px bg-border mb-6"></div>
				<p class="text-text-secondary text-sm leading-relaxed mb-4">
					If you use <strong class="text-text-primary">VS Code</strong> or <strong class="text-text-primary">GitHub Codespaces</strong>,
					the repo includes a ready-to-use Dev Container. It sets up Ruby, Node.js, PostgreSQL, and Redis automatically &mdash;
					no local installation needed.
				</p>
				<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-sm space-y-2">
					<p class="text-text-dim"># Option A: VS Code</p>
					<p class="text-text-secondary"><span class="text-phosphor">$</span> code inboxed/</p>
					<p class="text-text-secondary text-text-dim"># Then: Cmd+Shift+P &rarr; "Dev Containers: Reopen in Container"</p>
					<p class="mt-3 text-text-dim"># Option B: GitHub Codespaces</p>
					<p class="text-text-secondary text-text-dim"># Click "Code" &rarr; "Codespaces" &rarr; "Create codespace on master"</p>
				</div>
				<p class="text-text-secondary text-sm mt-4 leading-relaxed">
					The Dev Container runs the API, dashboard, and MCP in development mode with hot reload.
					PostgreSQL and Redis start as companion services. Ports are auto-forwarded.
				</p>
				<div class="bg-surface/50 border border-amber/20 rounded-xl p-4 mt-4 flex items-start gap-3">
					<span class="text-amber text-lg mt-0.5">!</span>
					<p class="text-text-secondary text-sm">
						The Dev Container is for <strong>contributing to Inboxed itself</strong>, not for running it as a service.
						For a running instance, use the Docker Compose setup above.
					</p>
				</div>
			</section>
		</div>

		<!-- ═══════════════════════════════════════════════════════ -->
		<!-- PRODUCTION / VPS TAB                                    -->
		<!-- ═══════════════════════════════════════════════════════ -->
		{:else}
		<div class="space-y-16">
			<!-- Overview -->
			<section>
				<div class="bg-surface/50 border border-border rounded-2xl p-8">
					<h3 class="font-display text-lg font-bold mb-3 text-phosphor">What you get</h3>
					<p class="text-text-secondary text-sm leading-relaxed mb-4">
						A production Inboxed instance accessible over HTTPS with real email receiving capabilities.
						Your team or CI/CD pipeline can use it from anywhere.
					</p>
					<div class="grid grid-cols-2 md:grid-cols-3 gap-4 mt-6">
						<div class="p-3 bg-base rounded-lg border border-border/50">
							<div class="font-mono text-xs text-phosphor mb-1">Dashboard</div>
							<div class="text-text-dim text-xs">inboxed.yourdomain.com</div>
						</div>
						<div class="p-3 bg-base rounded-lg border border-border/50">
							<div class="font-mono text-xs text-phosphor mb-1">API</div>
							<div class="text-text-dim text-xs">inboxed-api.yourdomain.com</div>
						</div>
						<div class="p-3 bg-base rounded-lg border border-border/50">
							<div class="font-mono text-xs text-cyan mb-1">SMTP</div>
							<div class="text-text-dim text-xs">mail.yourdomain.com:587</div>
						</div>
						<div class="p-3 bg-base rounded-lg border border-border/50">
							<div class="font-mono text-xs text-amber mb-1">MCP (HTTP)</div>
							<div class="text-text-dim text-xs">inboxed-mcp.yourdomain.com</div>
						</div>
						<div class="p-3 bg-base rounded-lg border border-border/50">
							<div class="font-mono text-xs text-cyan mb-1">Hooks</div>
							<div class="text-text-dim text-xs">inboxed-api.yourdomain.com/hook/:token</div>
						</div>
						<div class="p-3 bg-base rounded-lg border border-border/50">
							<div class="font-mono text-xs text-text-dim mb-1">Inbound Email</div>
							<div class="text-text-dim text-xs">*@mail.yourdomain.com (optional)</div>
						</div>
					</div>
				</div>
			</section>

			<!-- Prerequisites -->
			<section>
				<h2 class="font-display text-2xl font-bold mb-2">Prerequisites</h2>
				<div class="h-px bg-border mb-6"></div>
				<ul class="space-y-3 text-text-secondary text-sm">
					<li class="flex items-start gap-3">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div><strong class="text-text-primary">A VPS</strong> &mdash; any provider (Hetzner, DigitalOcean, Linode). A $6/month box with 2GB RAM is enough.</div>
					</li>
					<li class="flex items-start gap-3">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div><strong class="text-text-primary">A domain name</strong> &mdash; you'll create DNS records for dashboard, API, and optionally mail subdomains.</div>
					</li>
					<li class="flex items-start gap-3">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div><strong class="text-text-primary">Docker &amp; Docker Compose</strong> on the VPS.</div>
					</li>
					<li class="flex items-start gap-3">
						<span class="text-text-dim mt-0.5">&mdash;</span>
						<div><strong class="text-text-primary">Cloudflare account</strong> (optional) &mdash; for Tunnel (automatic HTTPS, no port opening) and/or Email Routing (receive real emails).</div>
					</li>
				</ul>
			</section>

			<!-- Step 1: VPS setup -->
			<section>
				<div class="flex items-center gap-4 mb-6">
					<span class="flex items-center justify-center size-10 rounded-full bg-phosphor/10 text-phosphor font-mono font-bold text-lg">1</span>
					<h2 class="font-display text-2xl font-bold">Deploy on VPS</h2>
				</div>
				<p class="text-text-secondary text-sm leading-relaxed mb-4">
					SSH into your VPS and run the same setup as local:
				</p>
				<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-sm space-y-2">
					<p class="text-text-secondary"><span class="text-phosphor">$</span> git clone {githubUrl} &amp;&amp; cd inboxed</p>
					<p class="text-text-secondary"><span class="text-phosphor">$</span> bin/setup</p>
					<p class="text-text-dim mt-2"># When prompted for domain, enter your actual domain:</p>
					<p class="text-text-secondary">  Domain [localhost]: <span class="text-phosphor">mail.yourdomain.com</span></p>
					<p class="text-text-secondary">  Dashboard port [80]: <span class="text-phosphor">80</span></p>
					<p class="text-text-secondary">  SMTP port [587]: <span class="text-phosphor">587</span></p>
				</div>
			</section>

			<!-- Step 2: .env tuning -->
			<section>
				<div class="flex items-center gap-4 mb-6">
					<span class="flex items-center justify-center size-10 rounded-full bg-phosphor/10 text-phosphor font-mono font-bold text-lg">2</span>
					<h2 class="font-display text-2xl font-bold">Tune .env for production</h2>
				</div>
				<p class="text-text-secondary text-sm leading-relaxed mb-4">
					After <code class="font-mono text-phosphor">bin/setup</code> generates the <code class="font-mono text-text-dim">.env</code>,
					edit it to set your actual URLs and any optional features:
				</p>
				<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-xs space-y-1">
					<p class="text-text-dim"># .env &mdash; production overrides</p>
					<p class="text-text-secondary">INBOXED_DOMAIN=<span class="text-phosphor">mail.yourdomain.com</span></p>
					<p class="text-text-secondary">INBOXED_BASE_URL=<span class="text-phosphor">https://inboxed-api.yourdomain.com</span></p>
					<p class="text-text-secondary">DASHBOARD_URL=<span class="text-phosphor">https://inboxed.yourdomain.com</span></p>
					<p class="mt-3 text-text-dim"># Registration: open, invite_only, or closed (default)</p>
					<p class="text-text-secondary">REGISTRATION_MODE=<span class="text-phosphor">closed</span></p>
					<p class="mt-3 text-text-dim"># Optional: outbound SMTP for email verification &amp; password reset</p>
					<p class="text-text-secondary">OUTBOUND_SMTP_HOST=<span class="text-phosphor">smtp.resend.com</span></p>
					<p class="text-text-secondary">OUTBOUND_FROM_EMAIL=<span class="text-phosphor">noreply@yourdomain.com</span></p>
					<p class="mt-3 text-text-dim"># Optional: GitHub OAuth login</p>
					<p class="text-text-secondary"># GITHUB_CLIENT_ID=...</p>
					<p class="text-text-secondary"># GITHUB_CLIENT_SECRET=...</p>
				</div>
				<p class="text-text-secondary text-sm mt-4">
					Then start the services: <code class="font-mono text-phosphor">docker compose up -d</code>
				</p>
			</section>

			<!-- Step 3: DNS -->
			<section>
				<div class="flex items-center gap-4 mb-6">
					<span class="flex items-center justify-center size-10 rounded-full bg-phosphor/10 text-phosphor font-mono font-bold text-lg">3</span>
					<h2 class="font-display text-2xl font-bold">DNS records</h2>
				</div>
				<p class="text-text-secondary text-sm leading-relaxed mb-4">
					Create the following DNS records pointing to your VPS IP (or Cloudflare if using Tunnel):
				</p>
				<div class="overflow-hidden border border-border rounded-xl">
					<table class="w-full text-left text-sm">
						<thead>
							<tr class="bg-surface border-b border-border">
								<th class="p-4 font-bold font-display text-xs uppercase tracking-wider">Type</th>
								<th class="p-4 font-bold font-display text-xs uppercase tracking-wider">Name</th>
								<th class="p-4 font-bold font-display text-xs uppercase tracking-wider">Value</th>
								<th class="p-4 font-bold font-display text-xs uppercase tracking-wider">Purpose</th>
							</tr>
						</thead>
						<tbody class="font-mono text-xs">
							<tr class="border-b border-border/50">
								<td class="p-4 text-amber">A</td>
								<td class="p-4">inboxed</td>
								<td class="p-4 text-text-secondary">&lt;VPS_IP&gt;</td>
								<td class="p-4 font-body text-text-dim">Dashboard</td>
							</tr>
							<tr class="border-b border-border/50">
								<td class="p-4 text-amber">A</td>
								<td class="p-4">inboxed-api</td>
								<td class="p-4 text-text-secondary">&lt;VPS_IP&gt;</td>
								<td class="p-4 font-body text-text-dim">REST API</td>
							</tr>
							<tr class="border-b border-border/50">
								<td class="p-4 text-amber">A</td>
								<td class="p-4">mail</td>
								<td class="p-4 text-text-secondary">&lt;VPS_IP&gt;</td>
								<td class="p-4 font-body text-text-dim">SMTP server</td>
							</tr>
							<tr class="border-b border-border/50 opacity-60">
								<td class="p-4 text-cyan">A</td>
								<td class="p-4">inboxed-mcp</td>
								<td class="p-4 text-text-secondary">&lt;VPS_IP&gt;</td>
								<td class="p-4 font-body text-text-dim">MCP HTTP (optional)</td>
							</tr>
							<tr class="opacity-60">
								<td class="p-4 text-cyan">MX</td>
								<td class="p-4">mail</td>
								<td class="p-4 text-text-secondary">mail.yourdomain.com</td>
								<td class="p-4 font-body text-text-dim">Inbound email (optional)</td>
							</tr>
						</tbody>
					</table>
				</div>
			</section>

			<!-- Step 4: HTTPS -->
			<section>
				<div class="flex items-center gap-4 mb-6">
					<span class="flex items-center justify-center size-10 rounded-full bg-phosphor/10 text-phosphor font-mono font-bold text-lg">4</span>
					<h2 class="font-display text-2xl font-bold">HTTPS &mdash; choose your approach</h2>
				</div>

				<!-- Option A: Reverse proxy -->
				<div class="bg-surface/50 border border-border rounded-2xl p-6 mb-6">
					<h4 class="font-display font-bold mb-2">Option A: Reverse proxy (Caddy / Nginx)</h4>
					<p class="text-text-secondary text-sm leading-relaxed mb-4">
						Use Caddy (auto-HTTPS) or Nginx + Let's Encrypt in front of the containers. The reverse proxy terminates TLS and forwards to the Docker services.
					</p>
					<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-xs space-y-1">
						<p class="text-text-dim"># Caddyfile example</p>
						<p class="text-text-secondary">inboxed.yourdomain.com &#123;</p>
						<p class="text-text-secondary">    reverse_proxy localhost:80</p>
						<p class="text-text-secondary">&#125;</p>
						<p class="text-text-secondary">inboxed-api.yourdomain.com &#123;</p>
						<p class="text-text-secondary">    reverse_proxy localhost:3100</p>
						<p class="text-text-secondary">&#125;</p>
						<p class="text-text-secondary">inboxed-mcp.yourdomain.com &#123;</p>
						<p class="text-text-secondary">    reverse_proxy localhost:3001</p>
						<p class="text-text-secondary">&#125;</p>
					</div>
				</div>

				<!-- Option B: Cloudflare Tunnel -->
				<div class="bg-surface/50 border border-cyan/20 rounded-2xl p-6">
					<div class="flex items-center gap-2 mb-2">
						<h4 class="font-display font-bold">Option B: Cloudflare Tunnel</h4>
						<span class="text-[10px] font-mono text-cyan bg-cyan/10 px-2 py-0.5 rounded-full">optional</span>
					</div>
					<p class="text-text-secondary text-sm leading-relaxed mb-4">
						No open ports, automatic HTTPS, DDoS protection. Install <code class="font-mono text-cyan">cloudflared</code> on the VPS and create a tunnel:
					</p>
					<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-xs space-y-2">
						<p class="text-text-dim"># Install cloudflared</p>
						<p class="text-text-secondary"><span class="text-cyan">$</span> curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared</p>
						<p class="text-text-secondary"><span class="text-cyan">$</span> chmod +x /usr/local/bin/cloudflared</p>
						<p class="text-text-secondary"><span class="text-cyan">$</span> cloudflared tunnel login</p>
						<p class="mt-3 text-text-dim"># Create tunnel</p>
						<p class="text-text-secondary"><span class="text-cyan">$</span> cloudflared tunnel create inboxed</p>
					</div>
					<p class="text-text-secondary text-sm mt-4 mb-4">
						Then configure the tunnel routes:
					</p>
					<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-xs space-y-1">
						<p class="text-text-dim"># ~/.cloudflared/config.yml</p>
						<p class="text-text-secondary">tunnel: &lt;TUNNEL_ID&gt;</p>
						<p class="text-text-secondary">credentials-file: /root/.cloudflared/&lt;TUNNEL_ID&gt;.json</p>
						<p class="text-text-secondary mt-2">ingress:</p>
						<p class="text-text-secondary">  - hostname: inboxed.yourdomain.com</p>
						<p class="text-text-secondary">    service: http://localhost:80</p>
						<p class="text-text-secondary">  - hostname: inboxed-api.yourdomain.com</p>
						<p class="text-text-secondary">    service: http://localhost:3100</p>
						<p class="text-text-secondary">  - hostname: inboxed-mcp.yourdomain.com</p>
						<p class="text-text-secondary">    service: http://localhost:3001</p>
						<p class="text-text-secondary">  - service: http_status:404</p>
					</div>
					<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-xs mt-4 space-y-2">
						<p class="text-text-dim"># Create DNS routes &amp; start</p>
						<p class="text-text-secondary"><span class="text-cyan">$</span> cloudflared tunnel route dns inboxed inboxed.yourdomain.com</p>
						<p class="text-text-secondary"><span class="text-cyan">$</span> cloudflared tunnel route dns inboxed inboxed-api.yourdomain.com</p>
						<p class="text-text-secondary"><span class="text-cyan">$</span> cloudflared tunnel route dns inboxed inboxed-mcp.yourdomain.com</p>
						<p class="text-text-secondary"><span class="text-cyan">$</span> cloudflared tunnel run inboxed</p>
					</div>
					<div class="bg-surface/50 border border-amber/20 rounded-xl p-4 mt-4 flex items-start gap-3">
						<span class="text-amber text-lg mt-0.5">!</span>
						<p class="text-text-secondary text-sm">
							Cloudflare Tunnel handles <strong>HTTP traffic only</strong>. The SMTP server (port 587) still needs direct access &mdash;
							open ports 587 and 465 on your VPS firewall for SMTP connections. Tunnel can't proxy SMTP.
						</p>
					</div>
				</div>
			</section>

			<!-- Step 5: Inbound Email -->
			<section>
				<div class="flex items-center gap-4 mb-6">
					<span class="flex items-center justify-center size-10 rounded-full bg-cyan/10 text-cyan font-mono font-bold text-lg">5</span>
					<h2 class="font-display text-2xl font-bold">Inbound email from the internet (optional)</h2>
				</div>
				<p class="text-text-secondary text-sm leading-relaxed mb-6">
					By default, the SMTP server only catches emails sent directly to it (your app &rarr; Inboxed).
					To receive real emails from external senders (e.g., <code class="font-mono text-text-dim">user@mail.yourdomain.com</code>),
					you have two options:
				</p>

				<!-- Option A: Direct SMTP -->
				<div class="bg-surface/50 border border-border rounded-2xl p-6 mb-6">
					<h4 class="font-display font-bold mb-2">Option A: Direct SMTP (port 25)</h4>
					<p class="text-text-secondary text-sm leading-relaxed mb-4">
						Open port 25 on your VPS and set up an MX record. Other mail servers will deliver directly to Inboxed's SMTP server.
					</p>
					<div class="overflow-hidden border border-border rounded-xl">
						<table class="w-full text-left text-sm">
							<thead>
								<tr class="bg-surface border-b border-border">
									<th class="p-3 font-bold font-display text-xs uppercase tracking-wider">Type</th>
									<th class="p-3 font-bold font-display text-xs uppercase tracking-wider">Name</th>
									<th class="p-3 font-bold font-display text-xs uppercase tracking-wider">Value</th>
								</tr>
							</thead>
							<tbody class="font-mono text-xs">
								<tr class="border-b border-border/50">
									<td class="p-3 text-amber">MX</td>
									<td class="p-3">mail.yourdomain.com</td>
									<td class="p-3 text-text-secondary">10 mail.yourdomain.com</td>
								</tr>
								<tr>
									<td class="p-3 text-amber">A</td>
									<td class="p-3">mail</td>
									<td class="p-3 text-text-secondary">&lt;VPS_IP&gt;</td>
								</tr>
							</tbody>
						</table>
					</div>
					<div class="bg-surface/50 border border-amber/20 rounded-xl p-4 mt-4 flex items-start gap-3">
						<span class="text-amber text-lg mt-0.5">!</span>
						<p class="text-text-secondary text-sm">
							Many cloud providers block port 25 by default. Check with your provider and request unblocking if needed.
						</p>
					</div>
				</div>

				<!-- Option B: Cloudflare Email Routing -->
				<div class="bg-surface/50 border border-cyan/20 rounded-2xl p-6">
					<div class="flex items-center gap-2 mb-2">
						<h4 class="font-display font-bold">Option B: Cloudflare Email Routing + Worker</h4>
						<span class="text-[10px] font-mono text-cyan bg-cyan/10 px-2 py-0.5 rounded-full">recommended</span>
					</div>
					<p class="text-text-secondary text-sm leading-relaxed mb-4">
						Cloudflare handles MX records and receives email on your behalf. A Worker forwards the email to Inboxed's API via webhook.
						No port 25 needed.
					</p>
					<ol class="space-y-4 text-text-secondary text-sm">
						<li class="flex items-start gap-3">
							<span class="text-cyan font-mono font-bold shrink-0">1.</span>
							<div>
								<strong class="text-text-primary">Enable Email Routing</strong> in Cloudflare dashboard &rarr; your domain &rarr; Email Routing.
								Cloudflare auto-creates the required MX and TXT records.
							</div>
						</li>
						<li class="flex items-start gap-3">
							<span class="text-cyan font-mono font-bold shrink-0">2.</span>
							<div>
								<strong class="text-text-primary">Deploy the Email Worker</strong> from the repo:
								<div class="bg-black rounded-xl border border-border/50 p-4 font-mono text-xs mt-2 space-y-2">
									<p><span class="text-cyan">$</span> cd cloudflare-email-worker</p>
									<p><span class="text-cyan">$</span> npx wrangler secret put INBOXED_API_URL</p>
									<p class="text-text-dim">  &rarr; https://inboxed-api.yourdomain.com</p>
									<p><span class="text-cyan">$</span> npx wrangler secret put INBOUND_WEBHOOK_SECRET</p>
									<p class="text-text-dim">  &rarr; (generate a secure token)</p>
									<p><span class="text-cyan">$</span> npx wrangler deploy</p>
								</div>
							</div>
						</li>
						<li class="flex items-start gap-3">
							<span class="text-cyan font-mono font-bold shrink-0">3.</span>
							<div>
								<strong class="text-text-primary">Route emails to the Worker</strong> &mdash; in Email Routing &rarr; Routes, add a catch-all route
								<code class="font-mono text-cyan">*@mail.yourdomain.com &rarr; Worker: inboxed-email-worker</code>.
							</div>
						</li>
						<li class="flex items-start gap-3">
							<span class="text-cyan font-mono font-bold shrink-0">4.</span>
							<div>
								<strong class="text-text-primary">Set the webhook secret</strong> in your Inboxed <code class="font-mono text-text-dim">.env</code>:
								<div class="bg-black rounded-xl border border-border/50 p-4 font-mono text-xs mt-2">
									<p class="text-text-secondary">INBOUND_WEBHOOK_SECRET=<span class="text-phosphor">&lt;same-token-as-worker&gt;</span></p>
									<p class="text-text-secondary">INBOXED_FEATURE_INBOUND_EMAIL=<span class="text-phosphor">true</span></p>
								</div>
							</div>
						</li>
					</ol>
					<p class="text-text-secondary text-sm mt-4">
						Now anyone can send email to <code class="font-mono text-phosphor">anything@mail.yourdomain.com</code> and it shows up in Inboxed.
					</p>
				</div>
			</section>

			<!-- Step 6: Create admin -->
			<section>
				<div class="flex items-center gap-4 mb-6">
					<span class="flex items-center justify-center size-10 rounded-full bg-phosphor/10 text-phosphor font-mono font-bold text-lg">6</span>
					<h2 class="font-display text-2xl font-bold">Create admin &amp; configure</h2>
				</div>
				<p class="text-text-secondary text-sm leading-relaxed">
					Open <code class="font-mono text-phosphor">https://inboxed.yourdomain.com/setup</code>, enter your setup token, and create the admin account.
					Then go to <strong class="text-text-primary">Settings</strong> to create projects, invite team members, and generate API keys.
				</p>
			</section>

			<!-- Architecture diagram -->
			<section>
				<h2 class="font-display text-2xl font-bold mb-2">Architecture overview</h2>
				<div class="h-px bg-border mb-6"></div>
				<div class="bg-black rounded-xl border border-border/50 p-6 font-mono text-xs leading-relaxed text-text-secondary">
<pre class="whitespace-pre overflow-x-auto">
Internet
  |
  +-- HTTPS (Caddy/Tunnel) ──+──  Dashboard (:80)
  |                           |
  |                           +──  API (:3100)  ──  PostgreSQL
  |                           |                  |
  |                           +──  MCP (:3001)   +──  Redis
  |
  +-- SMTP (:587/:465) ──────────  API (SMTP server)
  |
  +-- Cloudflare Email Routing ──  Worker ──  API /inbound webhook
       (optional)
</pre>
				</div>
			</section>

			<!-- Alternative: Kamal -->
			<section>
				<h2 class="font-display text-2xl font-bold mb-2">Alternative: Deploy with Kamal</h2>
				<div class="h-px bg-border mb-6"></div>
				<p class="text-text-secondary text-sm leading-relaxed mb-4">
					Instead of manually running <code class="font-mono text-phosphor">docker compose</code> on the VPS, you can use
					<a href="https://kamal-deploy.org" class="text-phosphor hover:underline" target="_blank" rel="noopener">Kamal</a> for
					zero-downtime deploys with automatic rolling updates. Inboxed ships with a ready-to-use
					<code class="font-mono text-text-dim">config/deploy.yml</code>.
				</p>
				<p class="text-text-secondary text-sm leading-relaxed mb-4">
					<strong class="text-text-primary">Recommended approach:</strong> fork the repo and configure your production secrets
					in the fork's environment. This way you can pull upstream updates and redeploy with a single command.
				</p>
				<div class="bg-black rounded-xl border border-border/50 p-5 font-mono text-xs space-y-2">
					<p class="text-text-dim"># 1. Fork the repo on GitHub</p>
					<p class="text-text-dim"># 2. Clone your fork</p>
					<p class="text-text-secondary"><span class="text-phosphor">$</span> git clone https://github.com/YOUR_USER/inboxed &amp;&amp; cd inboxed</p>
					<p class="mt-3 text-text-dim"># 3. Set your production secrets as GitHub Secrets or in .kamal/secrets</p>
					<p class="text-text-dim"># 4. Edit config/deploy.yml with your domain and VPS IP</p>
					<p class="mt-3 text-text-dim"># 5. Deploy</p>
					<p class="text-text-secondary"><span class="text-phosphor">$</span> kamal setup   <span class="text-text-dim"># first time &mdash; provisions everything</span></p>
					<p class="text-text-secondary"><span class="text-phosphor">$</span> kamal deploy  <span class="text-text-dim"># subsequent &mdash; zero-downtime update</span></p>
				</div>
				<p class="text-text-secondary text-sm mt-4 leading-relaxed">
					Kamal handles building Docker images, pushing to GHCR, deploying to the VPS, running database migrations,
					and managing accessories (PostgreSQL, Redis, MCP, Dashboard). The included
					<code class="font-mono text-text-dim">config/deploy.yml</code> defines all services and their environment variables.
				</p>
				<div class="bg-surface/50 border border-border rounded-xl p-4 mt-4 flex items-start gap-3">
					<span class="text-cyan text-lg mt-0.5">i</span>
					<p class="text-text-secondary text-sm">
						The repo also includes GitHub Actions workflows (<code class="font-mono text-text-dim">.github/workflows/deploy.yml</code>)
						that build Docker images and deploy automatically on push to <code class="font-mono text-text-dim">master</code>.
						Configure the required secrets in your fork's GitHub Settings &rarr; Secrets.
					</p>
				</div>
			</section>

			<!-- .env.example reference (production) -->
			<section>
				<h2 class="font-display text-2xl font-bold mb-2">Configuration reference</h2>
				<div class="h-px bg-border mb-6"></div>
				<p class="text-text-secondary text-sm leading-relaxed">
					See <code class="font-mono text-phosphor">.env.example</code> in the repo root for every available setting:
					feature flags, rate limits, SMTP tuning, storage limits, and infrastructure overrides.
					Each variable is documented with its purpose and default value.
				</p>
			</section>

			<!-- Production tips -->
			<section>
				<h2 class="font-display text-2xl font-bold mb-2">Production checklist</h2>
				<div class="h-px bg-border mb-6"></div>
				<div class="space-y-3">
					<div class="flex items-start gap-3 text-text-secondary text-sm">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div>Set <code class="font-mono text-text-dim">REGISTRATION_MODE=closed</code> or <code class="font-mono text-text-dim">invite_only</code> to prevent unwanted signups.</div>
					</div>
					<div class="flex items-start gap-3 text-text-secondary text-sm">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div>Configure <code class="font-mono text-text-dim">OUTBOUND_SMTP_HOST</code> for email verification and password resets (Resend, Postmark, etc.).</div>
					</div>
					<div class="flex items-start gap-3 text-text-secondary text-sm">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div>Set <code class="font-mono text-text-dim">EMAIL_TTL_HOURS</code> to auto-purge old emails and keep storage in check.</div>
					</div>
					<div class="flex items-start gap-3 text-text-secondary text-sm">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div>Back up the <code class="font-mono text-text-dim">pgdata</code> Docker volume regularly.</div>
					</div>
					<div class="flex items-start gap-3 text-text-secondary text-sm">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div>Firewall: only expose ports 80, 443 (HTTP/S), 587, 465 (SMTP). Keep 5432 (Postgres) and 6379 (Redis) internal.</div>
					</div>
					<div class="flex items-start gap-3 text-text-secondary text-sm">
						<span class="text-phosphor mt-0.5">&#10003;</span>
						<div>Keep your <code class="font-mono text-text-dim">.env</code> file secure (<code class="font-mono text-text-dim">chmod 600</code>) &mdash; it contains all secrets.</div>
					</div>
				</div>
			</section>
		</div>
		{/if}

		<!-- Footer CTA (both tabs) -->
		<section class="mt-24 pt-12 border-t border-border">
			<div class="text-center">
				<p class="text-text-secondary text-sm mb-4">Need help? Check the source or open an issue.</p>
				<div class="flex flex-col sm:flex-row gap-4 justify-center">
					<a href="{githubUrl}" class="px-6 py-3 bg-surface border border-border rounded-xl text-sm font-display font-bold hover:bg-surface-2 transition-colors text-center">
						GitHub Repository
					</a>
					<a href="{githubUrl}/issues" class="px-6 py-3 bg-surface border border-border rounded-xl text-sm font-display font-bold hover:bg-surface-2 transition-colors text-center">
						Report Issue
					</a>
				</div>
			</div>
		</section>
	</main>
</div>
