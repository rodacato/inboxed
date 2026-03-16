<script lang="ts">
	const githubUrl = 'https://github.com/notdefined-dev/inboxed';
</script>

<div class="min-h-screen bg-base text-text-primary antialiased overflow-x-hidden">
	<!-- Sticky Nav -->
	<nav class="fixed top-0 left-0 right-0 z-50 h-16 flex items-center bg-base/70 backdrop-blur-xl border-b border-phosphor/10">
		<div class="max-w-6xl mx-auto px-6 w-full flex items-center justify-between">
			<a href="/" class="flex items-center gap-2">
				<div class="size-7 bg-phosphor rounded-md flex items-center justify-center">
					<span class="material-symbols-outlined text-white dark:text-black" style="font-size: 18px;">alternate_email</span>
				</div>
				<span class="font-display text-xl font-bold tracking-tight">inboxed</span>
			</a>
			<div class="hidden md:flex items-center gap-8 text-sm font-medium text-text-secondary">
				<a href="#features" class="hover:text-phosphor transition-colors">Features</a>
				<a href="#how-it-works" class="hover:text-phosphor transition-colors">How It Works</a>
				<a href="#mcp" class="hover:text-cyan transition-colors">MCP</a>
				<a href="#api" class="hover:text-phosphor transition-colors">API</a>
				<a href="#pricing" class="hover:text-phosphor transition-colors">Pricing</a>
			</div>
			<div class="flex items-center gap-3">
				<a href="{githubUrl}" class="hidden sm:flex items-center gap-1.5 px-3 py-1.5 bg-surface border border-border rounded-full text-xs font-mono text-text-secondary hover:text-text-primary transition-colors">
					<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/></svg>
					Star
				</a>
				<a href="/register" class="px-5 py-2 bg-phosphor text-white dark:text-black text-sm font-display font-bold rounded-lg hover:brightness-110 transition-all glow-green">
					Try Free
				</a>
			</div>
		</div>
	</nav>

	<!-- Hero -->
	<header class="pt-40 pb-24 relative overflow-hidden">
		<!-- Ambient glow -->
		<div class="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] rounded-full -z-10 opacity-20 blur-[120px]" style="background: radial-gradient(ellipse, var(--color-phosphor), transparent 70%);"></div>

		<div class="max-w-6xl mx-auto px-6 text-center">
			<!-- Badge -->
			<div class="inline-flex items-center gap-2 px-4 py-2 bg-surface/50 border border-phosphor/15 rounded-full mb-8 backdrop-blur-sm">
				<span class="w-2 h-2 rounded-full bg-amber animate-pulse"></span>
				<span class="text-xs font-mono uppercase tracking-widest text-amber">Open Source &middot; Self-Hosted &middot; MIT License</span>
			</div>

			<h1 class="text-5xl md:text-8xl font-bold tracking-tighter mb-6 leading-tight font-display">
				The dev <span class="gradient-text-green">inbox.</span>
			</h1>

			<p class="text-text-secondary text-xl md:text-2xl max-w-2xl mx-auto mb-10 leading-relaxed">
				Capture SMTP, webhooks, and HTTP requests in one place.
				No third-party servers. No leak risks. Built for senior engineers.
			</p>

			<div class="flex flex-col sm:flex-row items-center justify-center gap-4">
				<a href="/register" class="w-full sm:w-auto px-8 py-4 bg-phosphor text-white dark:text-black font-bold rounded-xl text-lg hover:scale-105 transition-transform glow-green font-display text-center">
					Try Free <span class="opacity-60 text-sm ml-1">&mdash; 30 seconds</span>
				</a>
				<a href="#self-host" class="w-full sm:w-auto px-8 py-4 border border-border bg-surface/30 backdrop-blur-md text-text-primary font-bold rounded-xl text-lg hover:bg-surface transition-colors font-display text-center">
					Self-Host Guide
				</a>
			</div>
		</div>
	</header>

	<!-- Problem Statement -->
	<section class="py-20 bg-surface/20">
		<div class="max-w-4xl mx-auto px-6 text-center">
			<h2 class="text-3xl md:text-5xl font-medium font-display mb-8 leading-tight">
				"Your app talks to the outside world.<br>
				<span class="text-text-secondary">You have no idea what it said."</span>
			</h2>
			<div class="h-px w-full bg-gradient-to-r from-transparent via-amber/50 to-transparent mb-8"></div>
			<p class="text-amber font-mono uppercase tracking-[0.2em] text-sm">Stop guessing. Start inspecting.</p>
		</div>
	</section>

	<!-- Features -->
	<section id="features" class="py-24">
		<div class="max-w-6xl mx-auto px-6">
			<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
				<!-- Mail -->
				<div class="p-8 bg-surface border border-border rounded-2xl group hover:border-phosphor/40 transition-all">
					<div class="w-12 h-12 bg-phosphor/10 rounded-xl flex items-center justify-center mb-6">
						<span class="material-symbols-outlined text-phosphor" style="font-size: 24px;">mail</span>
					</div>
					<h3 class="text-xl font-bold font-display mb-3">SMTP Mail</h3>
					<p class="text-text-secondary text-sm leading-relaxed">
						Local SMTP server that traps everything. Preview HTML/Text/Raw headers. Attachments, MIME parsing, OTP extraction.
					</p>
				</div>

				<!-- Hooks -->
				<div class="p-8 bg-surface border border-border rounded-2xl group hover:border-cyan/40 transition-all">
					<div class="w-12 h-12 bg-cyan/10 rounded-xl flex items-center justify-center mb-6">
						<span class="material-symbols-outlined text-cyan" style="font-size: 24px;">webhook</span>
					</div>
					<h3 class="text-xl font-bold font-display mb-3">Webhooks</h3>
					<p class="text-text-secondary text-sm leading-relaxed">
						Catch external webhooks. Debug Stripe, GitHub, or Twilio events. Inspect method, headers, body, query params.
					</p>
				</div>

				<!-- Forms -->
				<div class="p-8 bg-surface border border-border rounded-2xl group hover:border-amber/40 transition-all">
					<div class="w-12 h-12 bg-amber/10 rounded-xl flex items-center justify-center mb-6">
						<span class="material-symbols-outlined text-amber" style="font-size: 24px;">dynamic_form</span>
					</div>
					<h3 class="text-xl font-bold font-display mb-3">Dev Forms</h3>
					<p class="text-text-secondary text-sm leading-relaxed">
						Point your frontend forms at Inboxed. See JSON payloads without a backend. Perfect for prototyping.
					</p>
				</div>

				<!-- Heartbeats -->
				<div class="p-8 bg-surface border border-border rounded-2xl group hover:border-phosphor/40 transition-all">
					<div class="w-12 h-12 bg-phosphor/10 rounded-xl flex items-center justify-center mb-6">
						<span class="material-symbols-outlined text-phosphor" style="font-size: 24px;">monitor_heart</span>
					</div>
					<h3 class="text-xl font-bold font-display mb-3">Heartbeats</h3>
					<p class="text-text-secondary text-sm leading-relaxed">
						Monitor cron jobs and background workers. Expect a ping every N minutes &mdash; get alerted when it doesn't arrive.
					</p>
				</div>
			</div>
		</div>
	</section>

	<!-- How It Works -->
	<section id="how-it-works" class="py-24 bg-surface/10 border-y border-border/50">
		<div class="max-w-6xl mx-auto px-6">
			<h2 class="text-4xl font-bold mb-16 text-center font-display">Engineered for speed.</h2>
			<div class="grid grid-cols-1 lg:grid-cols-3 gap-12">
				<!-- Step 1 -->
				<div class="relative pt-8">
					<span class="font-mono font-bold absolute -top-4 -left-2 select-none text-phosphor" style="font-size: 8rem; line-height: 1; opacity: 0.06;">1</span>
					<div class="relative">
						<h4 class="text-2xl font-bold font-display mb-4">Deploy</h4>
						<p class="text-text-secondary mb-6">One command to spin up Inboxed via Docker Compose.</p>
						<div class="bg-black dark:bg-black/80 p-4 rounded-xl border border-border/50 font-mono text-xs text-text-secondary">
							<span class="text-phosphor">$</span> git clone {githubUrl}<br>
							<span class="text-phosphor">$</span> bin/setup && docker compose up -d
						</div>
					</div>
				</div>

				<!-- Step 2 -->
				<div class="relative pt-8">
					<span class="font-mono font-bold absolute -top-4 -left-2 select-none text-cyan" style="font-size: 8rem; line-height: 1; opacity: 0.06;">2</span>
					<div class="relative">
						<h4 class="text-2xl font-bold font-display mb-4">Configure</h4>
						<p class="text-text-secondary mb-6">Point your app's SMTP to Inboxed. Three lines in .env.</p>
						<div class="bg-black dark:bg-black/80 p-4 rounded-xl border border-border/50 font-mono text-xs text-text-secondary">
							<span class="text-text-dim"># .env</span><br>
							SMTP_HOST=<span class="text-phosphor">localhost</span><br>
							SMTP_PORT=<span class="text-phosphor">2525</span>
						</div>
					</div>
				</div>

				<!-- Step 3 -->
				<div class="relative pt-8">
					<span class="font-mono font-bold absolute -top-4 -left-2 select-none text-amber" style="font-size: 8rem; line-height: 1; opacity: 0.06;">3</span>
					<div class="relative">
						<h4 class="text-2xl font-bold font-display mb-4">Inspect</h4>
						<p class="text-text-secondary mb-6">Open the dashboard and see every email, webhook, and form.</p>
						<div class="bg-black dark:bg-black/80 p-4 rounded-xl border border-border/50 font-mono text-xs flex items-center justify-between text-text-secondary">
							<span>Waiting for events...</span>
							<span class="w-2 h-2 bg-phosphor rounded-full animate-pulse"></span>
						</div>
					</div>
				</div>
			</div>
		</div>
	</section>

	<!-- Dashboard Preview (The Money Shot) -->
	<section class="py-24">
		<div class="max-w-6xl mx-auto px-6">
			<div class="rounded-2xl border border-border shadow-2xl overflow-hidden bg-surface" style="box-shadow: 0 20px 80px var(--color-phosphor-glow);">
				<!-- Browser chrome -->
				<div class="h-10 bg-base border-b border-border flex items-center px-4 gap-2">
					<div class="flex gap-1.5">
						<div class="w-3 h-3 rounded-full bg-error/50"></div>
						<div class="w-3 h-3 rounded-full bg-warning/50"></div>
						<div class="w-3 h-3 rounded-full bg-success/50"></div>
					</div>
					<div class="mx-auto bg-surface border border-border rounded px-4 py-0.5 text-[10px] font-mono text-text-dim">
						localhost/inbox
					</div>
				</div>

				<!-- App layout -->
				<div class="flex" style="height: 560px;">
					<!-- Sidebar -->
					<aside class="w-60 border-r border-border bg-base/50 p-4 space-y-2 hidden md:block">
						<div class="flex items-center gap-2 mb-6 px-2">
							<div class="size-6 bg-phosphor rounded flex items-center justify-center">
								<span class="material-symbols-outlined text-white dark:text-black" style="font-size: 14px;">alternate_email</span>
							</div>
							<span class="font-display text-sm font-bold">inboxed</span>
						</div>
						<div class="flex items-center gap-2 p-2.5 rounded-lg bg-phosphor/10 text-phosphor text-sm font-medium">
							<span class="material-symbols-outlined" style="font-size: 18px;">mail</span>
							Mail (12)
						</div>
						<div class="flex items-center gap-2 p-2.5 rounded-lg text-text-secondary text-sm hover:bg-surface">
							<span class="material-symbols-outlined" style="font-size: 18px;">webhook</span>
							Webhooks
						</div>
						<div class="flex items-center gap-2 p-2.5 rounded-lg text-text-secondary text-sm hover:bg-surface">
							<span class="material-symbols-outlined" style="font-size: 18px;">dynamic_form</span>
							Forms
						</div>
						<div class="flex items-center gap-2 p-2.5 rounded-lg text-text-secondary text-sm hover:bg-surface">
							<span class="material-symbols-outlined" style="font-size: 18px;">monitor_heart</span>
							Heartbeats
						</div>
					</aside>

					<!-- Message list -->
					<div class="w-full md:w-80 border-r border-border bg-base/30 overflow-y-auto">
						<div class="p-3 border-b border-border flex justify-between items-center">
							<span class="text-[10px] font-bold uppercase tracking-widest text-text-dim">Recent Messages</span>
							<button class="text-phosphor text-[10px] font-mono">Clear all</button>
						</div>
						<!-- Active email -->
						<div class="p-4 border-b border-phosphor/20 bg-phosphor/5 space-y-1 cursor-pointer">
							<div class="flex justify-between items-start">
								<span class="text-xs text-phosphor font-mono">auth-service</span>
								<span class="px-1.5 py-0.5 rounded bg-amber text-black dark:text-black text-[8px] font-bold">NEW</span>
							</div>
							<p class="text-sm font-bold truncate">Verify your email address</p>
							<p class="text-[10px] text-text-dim truncate">To: user_492@example.com</p>
						</div>
						<!-- Other emails -->
						<div class="p-4 border-b border-border space-y-1 opacity-60">
							<span class="text-xs text-text-dim font-mono">stripe-webhook</span>
							<p class="text-sm font-bold truncate">payment_intent.succeeded</p>
							<p class="text-[10px] text-text-dim truncate">ID: pi_3N9XkU2eZxc</p>
						</div>
						<div class="p-4 border-b border-border space-y-1 opacity-60">
							<span class="text-xs text-text-dim font-mono">marketing-bot</span>
							<p class="text-sm font-bold truncate">Welcome to the platform!</p>
							<p class="text-[10px] text-text-dim truncate">To: test@inboxed.dev</p>
						</div>
						<div class="p-4 border-b border-border space-y-1 opacity-40">
							<span class="text-xs text-text-dim font-mono">noreply</span>
							<p class="text-sm font-bold truncate">Password reset requested</p>
							<p class="text-[10px] text-text-dim truncate">To: admin@project.test</p>
						</div>
					</div>

					<!-- Email preview -->
					<main class="flex-1 bg-surface flex flex-col hidden lg:flex">
						<div class="p-6 border-b border-border">
							<div class="flex justify-between items-start mb-4">
								<div>
									<h2 class="text-xl font-bold font-display">Verify your email address</h2>
									<p class="text-sm text-text-secondary">From: <span class="text-text-primary font-mono text-xs">no-reply@acme.test</span></p>
									<p class="text-sm text-text-secondary">To: <span class="text-text-primary font-mono text-xs">user_492@example.com</span></p>
								</div>
								<div class="flex gap-2">
									<button class="p-2 border border-border rounded hover:bg-surface-2 transition-colors">
										<span class="material-symbols-outlined text-text-dim" style="font-size: 16px;">download</span>
									</button>
									<button class="p-2 border border-border rounded hover:bg-surface-2 transition-colors text-error">
										<span class="material-symbols-outlined" style="font-size: 16px;">delete</span>
									</button>
								</div>
							</div>
							<div class="flex gap-4 border-b border-border">
								<button class="px-4 py-2 border-b-2 border-phosphor text-sm text-phosphor font-medium">HTML</button>
								<button class="px-4 py-2 text-sm text-text-dim hover:text-text-primary">Plain Text</button>
								<button class="px-4 py-2 text-sm text-text-dim hover:text-text-primary">Headers</button>
								<button class="px-4 py-2 text-sm text-text-dim hover:text-text-primary">Raw Source</button>
							</div>
						</div>
						<!-- HTML email render (white background like real email) -->
						<div class="flex-1 p-6 overflow-auto">
							<div class="bg-white rounded-lg p-8 max-w-md mx-auto text-center space-y-6 shadow-sm">
								<div class="text-4xl">[@]</div>
								<h3 class="text-2xl font-bold text-slate-900 font-display">Verify your email</h3>
								<p class="text-slate-600 text-sm">Please use the code below to verify your account registration.</p>
								<div class="bg-slate-100 py-4 text-3xl font-mono font-bold tracking-widest text-slate-800 rounded-lg">
									842-109
								</div>
								<p class="text-xs text-slate-400">If you didn't request this, ignore this email.</p>
							</div>
						</div>
					</main>
				</div>
			</div>
		</div>
	</section>

	<!-- Terminal Demo -->
	<section class="py-24 bg-black dark:bg-black">
		<div class="max-w-3xl mx-auto px-6">
			<div class="rounded-xl overflow-hidden border border-neutral-800" style="box-shadow: 0 20px 50px rgba(0,0,0,0.5);">
				<div class="flex items-center gap-2 px-4 py-2.5 bg-neutral-900 border-b border-neutral-800">
					<div class="w-3 h-3 rounded-full bg-neutral-700"></div>
					<span class="text-[10px] font-mono text-neutral-500 uppercase ml-1">Terminal &mdash; zsh</span>
				</div>
				<div class="p-6 font-mono text-sm leading-relaxed bg-black min-h-[300px]">
					<p class="text-neutral-500 mb-2"># Install and start Inboxed</p>
					<p class="text-neutral-300"><span class="text-[#39FF14]">$</span> git clone {githubUrl} && cd inboxed</p>
					<p class="text-neutral-300"><span class="text-[#39FF14]">$</span> bin/setup && docker compose up -d</p>
					<p class="mt-4 text-[#39FF14]">&#10003; PostgreSQL ready</p>
					<p class="text-[#39FF14]">&#10003; API ready on :3000</p>
					<p class="text-[#39FF14]">&#10003; Dashboard ready on :80</p>
					<p class="text-[#00E5FF]">&#10003; SMTP ready on :2525</p>
					<p class="text-[#00E5FF]">&#10003; MCP server ready</p>
					<p class="mt-4 text-neutral-300"><span class="text-[#39FF14]">$</span> swaks --to test@localhost --server localhost:2525</p>
					<p class="text-neutral-500">&rarr; 250 OK &mdash; email captured</p>
					<p class="mt-4 flex items-center">
						<span class="text-[#39FF14]">$</span>
						<span class="w-2 h-5 bg-[#39FF14] cursor-blink ml-1"></span>
					</p>
				</div>
			</div>
		</div>
	</section>

	<!-- MCP Section -->
	<section id="mcp" class="py-24 bg-surface/20">
		<div class="max-w-6xl mx-auto px-6">
			<div class="flex flex-col lg:flex-row items-center gap-16">
				<!-- Left: text -->
				<div class="lg:w-1/2">
					<div class="inline-flex items-center gap-2 px-3 py-1 bg-cyan/10 border border-cyan/30 rounded-full mb-6">
						<span class="text-[10px] font-bold tracking-widest text-cyan uppercase font-mono">MCP Ready</span>
					</div>
					<h2 class="text-4xl md:text-5xl font-bold font-display mb-6 leading-tight">
						AI agent integration via Model Context Protocol.
					</h2>
					<p class="text-text-secondary text-lg mb-8">
						Let your AI agents "read" the emails your app sends. Perfect for
						automating E2E testing flows that require OTP extraction or magic
						link clicks.
					</p>
					<ul class="space-y-4">
						<li class="flex items-start gap-3">
							<span class="text-cyan font-bold font-mono">01.</span>
							<span>Claude Code and Cursor can browse your dev mailbox.</span>
						</li>
						<li class="flex items-start gap-3">
							<span class="text-cyan font-bold font-mono">02.</span>
							<span>Automate sign-up flows in Playwright and Cypress.</span>
						</li>
						<li class="flex items-start gap-3">
							<span class="text-cyan font-bold font-mono">03.</span>
							<span>Works with n8n, LangChain, and any MCP-compatible agent.</span>
						</li>
					</ul>
				</div>

				<!-- Right: agent card -->
				<div class="lg:w-1/2 w-full">
					<div class="bg-surface border border-cyan/30 rounded-2xl p-6 glow-cyan">
						<div class="flex items-center gap-3 mb-6">
							<div class="w-8 h-8 rounded-full bg-cyan flex items-center justify-center">
								<span class="material-symbols-outlined text-black" style="font-size: 18px;">psychology</span>
							</div>
							<span class="font-bold font-display">Claude (AI Agent)</span>
						</div>
						<div class="bg-base/50 p-4 rounded-xl border border-border/30 mb-4">
							<p class="text-sm italic text-text-secondary">"I'll check the dev inbox for the verification code..."</p>
						</div>
						<div class="bg-base p-4 rounded-xl border border-cyan/20 font-mono text-[11px] space-y-1">
							<p class="text-cyan">CALL inboxed.wait_for_email(&#123; to: "test@mail.inboxed.dev" &#125;)</p>
							<p class="text-text-dim">FOUND: 1 message from no-reply@acme.test</p>
							<p class="text-cyan">CALL inboxed.extract_code(&#123; email_id: "em_a1b2c3" &#125;)</p>
							<p class="text-phosphor">RESULT: &#123; "code": "842-109" &#125;</p>
						</div>
					</div>
				</div>
			</div>

			<!-- MCP tools grid -->
			<div class="mt-16 grid grid-cols-2 md:grid-cols-4 gap-4">
				<div class="bg-surface rounded-xl p-4 border border-border text-center">
					<div class="font-mono text-sm text-cyan mb-1">list_inboxes</div>
					<div class="text-text-dim text-xs">Browse all inboxes</div>
				</div>
				<div class="bg-surface rounded-xl p-4 border border-border text-center">
					<div class="font-mono text-sm text-cyan mb-1">wait_for_email</div>
					<div class="text-text-dim text-xs">Long-poll for new mail</div>
				</div>
				<div class="bg-surface rounded-xl p-4 border border-border text-center">
					<div class="font-mono text-sm text-cyan mb-1">extract_code</div>
					<div class="text-text-dim text-xs">Get OTP from email</div>
				</div>
				<div class="bg-surface rounded-xl p-4 border border-border text-center">
					<div class="font-mono text-sm text-cyan mb-1">get_email</div>
					<div class="text-text-dim text-xs">Full email details</div>
				</div>
			</div>
		</div>
	</section>

	<!-- API Showcase -->
	<section id="api" class="py-24">
		<div class="max-w-6xl mx-auto px-6">
			<div class="text-center mb-16">
				<h2 class="text-3xl font-bold font-display mb-4">Everything is an API.</h2>
				<p class="text-text-secondary">Simple REST endpoints for your CI/CD pipelines.</p>
			</div>

			<div class="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-5xl mx-auto">
				<div class="bg-base dark:bg-black/80 p-6 rounded-2xl border border-border">
					<div class="flex items-center justify-between mb-4">
						<span class="text-xs font-mono text-phosphor uppercase">GET /api/v1/emails</span>
						<span class="text-[10px] text-text-dim">List emails</span>
					</div>
					<pre class="text-xs text-text-secondary font-mono leading-relaxed">&#123;
  <span class="text-cyan">"data"</span>: [
    &#123;
      <span class="text-cyan">"id"</span>: <span class="text-amber">"em_a1b2c3"</span>,
      <span class="text-cyan">"from"</span>: <span class="text-amber">"noreply@acme.test"</span>,
      <span class="text-cyan">"subject"</span>: <span class="text-amber">"Your OTP is 847291"</span>,
      <span class="text-cyan">"received_at"</span>: <span class="text-amber">"2026-03-16T14:32Z"</span>
    &#125;
  ],
  <span class="text-cyan">"meta"</span>: &#123; <span class="text-cyan">"total"</span>: <span class="text-phosphor">12</span> &#125;
&#125;</pre>
				</div>

				<div class="bg-base dark:bg-black/80 p-6 rounded-2xl border border-border">
					<div class="flex items-center justify-between mb-4">
						<span class="text-xs font-mono text-amber uppercase">GET /api/v1/emails/wait</span>
						<span class="text-[10px] text-text-dim">Long polling</span>
					</div>
					<pre class="text-xs text-text-secondary font-mono leading-relaxed"><span class="text-text-dim"># Pause test until email arrives</span>
curl localhost:3000/api/v1/emails/wait \
  -H <span class="text-amber">"Authorization: Bearer sk_..."</span> \
  -d <span class="text-amber">"to=signup@test"</span> \
  -d <span class="text-amber">"timeout=30"</span>

<span class="text-text-dim"># Returns immediately when email arrives</span>
&#123; <span class="text-cyan">"code"</span>: <span class="text-amber">"847291"</span> &#125;</pre>
				</div>
			</div>

			<!-- Client libraries -->
			<div class="mt-8 flex flex-col sm:flex-row gap-4 justify-center">
				<div class="flex items-center gap-3 px-6 py-3 bg-surface rounded-lg border border-border">
					<span class="font-mono text-sm text-amber">npm</span>
					<span class="font-mono text-sm text-text-secondary">@inboxed/client</span>
				</div>
				<div class="flex items-center gap-3 px-6 py-3 bg-surface rounded-lg border border-border">
					<span class="font-mono text-sm text-error">gem</span>
					<span class="font-mono text-sm text-text-secondary">inboxed-ruby</span>
				</div>
				<div class="flex items-center gap-3 px-6 py-3 bg-surface rounded-lg border border-border">
					<span class="font-mono text-sm text-cyan">curl</span>
					<span class="font-mono text-sm text-text-secondary">REST API</span>
				</div>
			</div>
		</div>
	</section>

	<!-- Comparison Table -->
	<section class="py-24 bg-surface/20">
		<div class="max-w-4xl mx-auto px-6">
			<h2 class="text-3xl font-bold mb-12 text-center font-display">Built by devs, for devs.</h2>
			<div class="overflow-hidden border border-border rounded-2xl">
				<table class="w-full text-left border-collapse text-sm">
					<thead>
						<tr class="bg-surface border-b border-border">
							<th class="p-5 font-bold font-display">Feature</th>
							<th class="p-5 font-bold text-phosphor font-display">Inboxed</th>
							<th class="p-5 font-bold text-text-dim font-display">Mailtrap</th>
							<th class="p-5 font-bold text-text-dim font-display hidden sm:table-cell">Mailpit</th>
						</tr>
					</thead>
					<tbody>
						<tr class="border-b border-border/50">
							<td class="p-5">Self-Hosted</td>
							<td class="p-5 text-phosphor">&#10003; Yes</td>
							<td class="p-5 text-text-dim">&mdash; Cloud only</td>
							<td class="p-5 text-phosphor hidden sm:table-cell">&#10003; Yes</td>
						</tr>
						<tr class="border-b border-border/50">
							<td class="p-5">MCP / AI Agents</td>
							<td class="p-5 text-phosphor">&#10003; Native</td>
							<td class="p-5 text-text-dim">&mdash; None</td>
							<td class="p-5 text-text-dim hidden sm:table-cell">&mdash; None</td>
						</tr>
						<tr class="border-b border-border/50">
							<td class="p-5">Webhook Debugging</td>
							<td class="p-5 text-phosphor">&#10003; Integrated</td>
							<td class="p-5 text-text-dim">&mdash; External</td>
							<td class="p-5 text-text-dim hidden sm:table-cell">&mdash; None</td>
						</tr>
						<tr class="border-b border-border/50">
							<td class="p-5">Form Catcher</td>
							<td class="p-5 text-phosphor">&#10003; Built-in</td>
							<td class="p-5 text-text-dim">&mdash; None</td>
							<td class="p-5 text-text-dim hidden sm:table-cell">&mdash; None</td>
						</tr>
						<tr class="border-b border-border/50">
							<td class="p-5">Data Persistence</td>
							<td class="p-5 text-phosphor">&#10003; PostgreSQL</td>
							<td class="p-5 text-text-dim">Cloud storage</td>
							<td class="p-5 text-text-dim hidden sm:table-cell">In-memory</td>
						</tr>
						<tr class="border-b border-border/50">
							<td class="p-5">Client Libraries</td>
							<td class="p-5 text-phosphor font-mono text-xs">TS + Ruby</td>
							<td class="p-5 text-text-dim">&mdash;</td>
							<td class="p-5 text-text-dim hidden sm:table-cell">&mdash;</td>
						</tr>
						<tr>
							<td class="p-5">Price</td>
							<td class="p-5 text-phosphor font-bold">Free / MIT</td>
							<td class="p-5 text-text-dim">$15-50/mo</td>
							<td class="p-5 text-phosphor hidden sm:table-cell">Free / MIT</td>
						</tr>
					</tbody>
				</table>
			</div>
		</div>
	</section>

	<!-- Pricing -->
	<section id="pricing" class="py-24">
		<div class="max-w-6xl mx-auto px-6">
			<div class="text-center mb-16">
				<h2 class="text-4xl font-bold font-display mb-4">Simple Pricing.</h2>
				<p class="text-text-secondary">Actually, it's basically free.</p>
			</div>

			<div class="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-4xl mx-auto">
				<!-- Cloud Sandbox -->
				<div class="p-10 bg-surface border border-border rounded-3xl">
					<h3 class="text-2xl font-bold font-display mb-2">Cloud Sandbox</h3>
					<div class="text-4xl font-bold mb-1 font-display">$0 <span class="text-sm font-normal text-text-dim">/ forever</span></div>
					<p class="text-text-dim text-sm mb-8 font-mono">cloud.inboxed.dev</p>
					<ul class="space-y-4 mb-10 text-text-secondary text-sm">
						<li class="flex items-center gap-2">
							<span class="text-phosphor">&#10003;</span> 50 messages retained
						</li>
						<li class="flex items-center gap-2">
							<span class="text-phosphor">&#10003;</span> 1-hour retention
						</li>
						<li class="flex items-center gap-2">
							<span class="text-phosphor">&#10003;</span> No credit card
						</li>
						<li class="flex items-center gap-2">
							<span class="text-phosphor">&#10003;</span> REST API access
						</li>
						<li class="flex items-center gap-2">
							<span class="text-text-dim">&mdash;</span>
							<span class="text-text-dim">MCP (self-host only)</span>
						</li>
					</ul>
					<a href="/register" class="block w-full py-4 bg-phosphor text-white dark:text-black font-bold rounded-xl hover:brightness-110 transition-all text-center font-display">
						Start Now
					</a>
				</div>

				<!-- Self-Host -->
				<div id="self-host" class="p-10 bg-surface border-2 border-phosphor/40 rounded-3xl relative">
					<div class="absolute -top-4 left-1/2 -translate-x-1/2 bg-phosphor text-white dark:text-black px-4 py-1 rounded-full text-[10px] font-bold uppercase tracking-widest font-mono">
						Recommended
					</div>
					<h3 class="text-2xl font-bold font-display mb-2">Self-Hosted</h3>
					<div class="text-4xl font-bold mb-1 font-display">Free <span class="text-sm font-normal text-text-dim">/ MIT License</span></div>
					<p class="text-text-dim text-sm mb-8 font-mono">docker compose up</p>
					<ul class="space-y-4 mb-10 text-text-secondary text-sm">
						<li class="flex items-center gap-2">
							<span class="text-phosphor">&#10003;</span> Unlimited everything
						</li>
						<li class="flex items-center gap-2">
							<span class="text-phosphor">&#10003;</span> MCP server for AI agents
						</li>
						<li class="flex items-center gap-2">
							<span class="text-phosphor">&#10003;</span> HTML email preview
						</li>
						<li class="flex items-center gap-2">
							<span class="text-phosphor">&#10003;</span> Fully private & local
						</li>
						<li class="flex items-center gap-2">
							<span class="text-phosphor">&#10003;</span> Your data, your server
						</li>
					</ul>
					<a href="{githubUrl}#quickstart" class="block w-full py-4 border-2 border-phosphor text-phosphor font-bold rounded-xl hover:bg-phosphor hover:text-white dark:hover:text-black transition-all text-center font-display">
						Read Documentation
					</a>
				</div>
			</div>
		</div>
	</section>

	<!-- FAQ -->
	<section class="py-24 bg-surface/10">
		<div class="max-w-3xl mx-auto px-6">
			<h2 class="text-3xl font-bold mb-12 text-center font-display">FAQ</h2>
			<div class="space-y-4">
				<details class="bg-surface border border-border rounded-2xl group" open>
					<summary class="p-6 font-bold font-display cursor-pointer list-none flex items-center justify-between">
						Is this a production email server?
						<span class="text-text-dim group-open:rotate-45 transition-transform text-xl">+</span>
					</summary>
					<p class="px-6 pb-6 text-sm text-text-secondary leading-relaxed">
						No. Inboxed is a development and testing tool. It catches emails &mdash; it never delivers them to real inboxes.
						It's a readable <code class="font-mono text-phosphor">/dev/null</code>.
					</p>
				</details>

				<details class="bg-surface border border-border rounded-2xl group">
					<summary class="p-6 font-bold font-display cursor-pointer list-none flex items-center justify-between">
						What do I need to self-host?
						<span class="text-text-dim group-open:rotate-45 transition-transform text-xl">+</span>
					</summary>
					<p class="px-6 pb-6 text-sm text-text-secondary leading-relaxed">
						Any machine with Docker and Docker Compose. A $6/month Hetzner VPS is more than enough.
						<code class="font-mono text-phosphor">bin/setup && docker compose up -d</code> and you're done.
					</p>
				</details>

				<details class="bg-surface border border-border rounded-2xl group">
					<summary class="p-6 font-bold font-display cursor-pointer list-none flex items-center justify-between">
						What is MCP and why does it matter?
						<span class="text-text-dim group-open:rotate-45 transition-transform text-xl">+</span>
					</summary>
					<p class="px-6 pb-6 text-sm text-text-secondary leading-relaxed">
						MCP (Model Context Protocol) lets AI agents call tools directly. Your agent calls
						<code class="font-mono text-cyan">extract_code("test@mail.inboxed.dev")</code>
						and gets the OTP. Works with Claude Code, Cursor, n8n, and any MCP-compatible agent.
					</p>
				</details>

				<details class="bg-surface border border-border rounded-2xl group">
					<summary class="p-6 font-bold font-display cursor-pointer list-none flex items-center justify-between">
						Can I use Inboxed in CI/CD?
						<span class="text-text-dim group-open:rotate-45 transition-transform text-xl">+</span>
					</summary>
					<p class="px-6 pb-6 text-sm text-text-secondary leading-relaxed">
						Yes. Use the REST API or client libraries (TypeScript, Ruby) to assert on emails in your test suite.
						<code class="font-mono text-cyan">wait_for_email</code> long-polls until the email arrives &mdash; no hardcoded sleeps.
					</p>
				</details>

				<details class="bg-surface border border-border rounded-2xl group">
					<summary class="p-6 font-bold font-display cursor-pointer list-none flex items-center justify-between">
						Is my data safe on the cloud trial?
						<span class="text-text-dim group-open:rotate-45 transition-transform text-xl">+</span>
					</summary>
					<p class="px-6 pb-6 text-sm text-text-secondary leading-relaxed">
						Cloud trial data has a 1-hour TTL and is automatically purged. No HTML rendering in cloud mode.
						For full control, self-host &mdash; no telemetry, no phone-home.
					</p>
				</details>
			</div>
		</div>
	</section>

	<!-- Footer -->
	<footer class="py-20 border-t border-border">
		<div class="max-w-6xl mx-auto px-6">
			<div class="grid grid-cols-2 md:grid-cols-4 gap-12 mb-20">
				<div class="col-span-2 md:col-span-1">
					<div class="flex items-center gap-2 mb-6">
						<div class="size-6 bg-phosphor rounded flex items-center justify-center">
							<span class="material-symbols-outlined text-white dark:text-black" style="font-size: 14px;">alternate_email</span>
						</div>
						<span class="font-display font-bold text-xl tracking-tight">inboxed</span>
					</div>
					<p class="text-text-secondary text-sm leading-relaxed max-w-xs">
						Open source SMTP server for modern development teams. Trap, inspect, and automate.
					</p>
				</div>
				<div>
					<h5 class="font-bold mb-6 text-sm uppercase tracking-widest font-display">Product</h5>
					<ul class="space-y-4 text-sm text-text-secondary">
						<li><a href="#features" class="hover:text-phosphor transition-colors">Features</a></li>
						<li><a href="#mcp" class="hover:text-phosphor transition-colors">MCP Server</a></li>
						<li><a href="#api" class="hover:text-phosphor transition-colors">REST API</a></li>
						<li><a href="#pricing" class="hover:text-phosphor transition-colors">Pricing</a></li>
					</ul>
				</div>
				<div>
					<h5 class="font-bold mb-6 text-sm uppercase tracking-widest font-display">Resources</h5>
					<ul class="space-y-4 text-sm text-text-secondary">
						<li><a href="{githubUrl}" class="hover:text-phosphor transition-colors">GitHub</a></li>
						<li><a href="{githubUrl}#quickstart" class="hover:text-phosphor transition-colors">Documentation</a></li>
						<li><a href="{githubUrl}/blob/main/CONTRIBUTING.md" class="hover:text-phosphor transition-colors">Contributing</a></li>
						<li><a href="{githubUrl}/blob/main/CHANGELOG.md" class="hover:text-phosphor transition-colors">Changelog</a></li>
					</ul>
				</div>
				<div>
					<h5 class="font-bold mb-6 text-sm uppercase tracking-widest font-display">Legal</h5>
					<ul class="space-y-4 text-sm text-text-secondary">
						<li><a href="/privacy" class="hover:text-phosphor transition-colors">Privacy Policy</a></li>
						<li><a href="/terms" class="hover:text-phosphor transition-colors">Terms of Service</a></li>
						<li><a href="{githubUrl}/blob/main/SECURITY.md" class="hover:text-phosphor transition-colors">Security</a></li>
						<li><a href="{githubUrl}/blob/main/LICENSE" class="hover:text-phosphor transition-colors">MIT License</a></li>
					</ul>
				</div>
			</div>

			<div class="flex flex-col md:flex-row justify-between items-center pt-8 border-t border-border text-[10px] text-text-dim uppercase tracking-[0.2em] font-mono">
				<p>&copy; 2025 Inboxed. Built by <a href="https://notdefined.dev" class="text-text-secondary hover:text-phosphor transition-colors">notdefined.dev</a></p>
				<div class="flex items-center gap-6 mt-4 md:mt-0">
					<a href="/login" class="text-text-secondary hover:text-phosphor transition-colors">Sign in</a>
					<a href="/register" class="text-phosphor">Try Free</a>
				</div>
			</div>
		</div>
	</footer>
</div>
