# AI-Assisted Project Workflow

> How to go from zero to a fully documented, architected, and scaffolded project using an LLM agent as your development partner.

This document captures the workflow used to build **Inboxed** from scratch — from the initial idea to a working three-service monorepo with full documentation, architecture specs, ADRs, branding, and dev environment. Every step is designed to be replicable for any new project.

---

## Philosophy

This workflow treats **documentation as the foundation, not an afterthought**. Before writing a single line of application code, you build a complete picture of *what* you're building, *why*, and *how*. Your LLM agent becomes your collaborator — not just a code generator, but a thinking partner for architecture, branding, and decision-making.

The key insight: **the better you document upfront, the better any LLM agent performs in every future conversation.** Files like `AGENTS.md`, `IDENTITY.md`, and specs become persistent context that shapes every interaction. This workflow is tool-agnostic — it works with Claude Code, Cursor, Windsurf, Copilot, Aider, or any agent that reads project files for context.

---

## The Workflow, Step by Step

### Step 0 — Research & Competitive Analysis

Before writing any code or documentation, understand the landscape. Use AI tools for deep research so you enter the project with informed opinions, not assumptions.

**What to research:**
- Existing solutions (competitors, open source alternatives)
- Technical approaches others have taken (and their tradeoffs)
- Domain-specific knowledge you'll need (protocols, standards, RFCs)
- Target user pain points (forums, GitHub issues, Reddit threads)

**Tools for research:**

| Tool | Best for | How to use |
|------|----------|-----------|
| **AI research tools** (Google AI Studio, ChatGPT, Claude) | Deep research on a domain, generating structured analysis | Prompt: "Research the landscape of [domain]. Compare existing tools, their architecture, pros/cons, and gaps. Present findings in a structured format." |
| **LLM chat** (Claude, ChatGPT, Gemini) | Brainstorming, refining ideas, exploring tradeoffs | Have a long conversation exploring your idea from multiple angles before committing to any decisions |
| **Your coding agent + web search** | Technical research while in your dev environment | `"Search for how [framework X] handles [problem Y] and summarize the common patterns"` |

**How we did it for Inboxed:**
1. Used an AI research tool to research email testing tools (Mailtrap, Mailpit, Mailinator, MailHog) — their features, architectures, pricing, and gaps
2. Generated a competitive analysis comparing self-hosted vs SaaS approaches
3. Identified the gap: no tool offers native MCP/AI agent integration
4. Researched SMTP protocol specifics (RFCs, libraries, TLS handling)

**How to prompt your agent:**
```
"I have an idea for a project. Here's the problem: [describe it].
Help me refine the scope — what should be in v1, what's out of scope,
and who exactly is the target user."
```

> **Tip:** Save your research outputs as files in the repo (e.g., `research_competitive.md`). You can add them to `.gitignore` if they're just for reference. They become useful context for your agent when making architectural decisions later.

> **Tip:** Don't skip competitive analysis even for novel ideas. Understanding what exists — even in adjacent spaces — prevents you from reinventing solved problems and helps you articulate your differentiator clearly.

---

### Step 1 — DevContainer & Dev Environment

Set up the development environment **first**, before anything else. This ensures every future conversation with your LLM agent happens inside a consistent, reproducible environment. In a devcontainer, your agent has access to the exact same tools, databases, and runtimes you'll use.

**Why devcontainer first:**
- Your agent runs commands in the same environment you develop in
- No "works on my machine" — the container IS the machine
- Databases and services are always available (PostgreSQL, Redis, etc.)
- New contributors (or new machines) get the full environment with zero setup

**What to create:**

```
.devcontainer/
├── devcontainer.json    # VS Code / GitHub Codespaces config
├── docker-compose.yml   # Services: workspace + databases
├── Dockerfile           # Base image with languages and tools
└── post-install.sh      # Dependency installation, aliases, tooling
```

**devcontainer.json essentials:**
- `features` — install languages and tools (Ruby, Node, PostgreSQL client, GitHub CLI)
- `forwardPorts` — expose service ports to the host (use non-default ports)
- `portsAttributes` — label each port so you know what's what
- `postCreateCommand` — run setup script after container creation
- `customizations.vscode.extensions` — install extensions automatically

**How to prompt your agent:**
```
"Set up a devcontainer for a project with these requirements:
- Languages: [Ruby 3.3, Node 22]
- Databases: [PostgreSQL 16, Redis 7]
- The workspace should have all languages installed natively, with
  databases running as separate Docker services.
- Forward ports: [list them with labels]
- Post-install: install dependencies for all apps, configure shell aliases
- Include VS Code extensions for [Ruby, Svelte, Tailwind, ESLint, Docker]"
```

**Key decisions at this stage:**
- Monorepo vs polyrepo (monorepo is simpler for small teams)
- Which services run in the devcontainer vs as Docker services (databases as services, app code runs natively)
- Port assignments — pick non-default ports early to avoid collisions
- What goes in `post-install.sh` vs `Dockerfile` (install deps in post-install so rebuilds are faster)

> **Tip:** Use `network_mode: service:db` in the workspace service to share the network with your database — this lets you use `localhost` to connect to PostgreSQL from your app code, just like in production with a sidecar database.

> **Tip:** Create persistent volumes for package caches (`bundle-cache`, `node-modules-cache`) so container rebuilds don't re-download everything.

> **Tip:** Always test your devcontainer by rebuilding it from scratch. If `postCreateCommand` fails, every new contributor will have a broken setup.

**Commit:** `chore: set up monorepo infrastructure and devcontainer`

---

### Step 2 — Project Identity (IDENTITY.md)

Define *who is building this* and *how they make decisions*. This file calibrates your LLM agent's responses to your experience level, stack preferences, and architectural principles.

**What to include:**
- Your role and technical profile
- Core stack with rationale for each choice
- Domain-specific knowledge (for Inboxed: email protocols, RFCs)
- Architecture principles (event-driven, hexagonal, convention-over-config, etc.)
- Decision-making framework (e.g., "Does it work on a single VPS?", "Can I ship it this week?")

**How to prompt your agent:**
```
"Help me create an IDENTITY.md for this project. I'm a [role] with deep
experience in [technologies]. My priorities are [list them]. The project
is a [type] for [audience]. Include a decision-making framework."
```

**Why this matters:** Without IDENTITY.md, your agent defaults to generic advice. With it, responses are calibrated to your actual experience — no over-explaining basics, no suggesting technologies outside your stack.

> **Tip:** Include a "Stack Selection Rationale" table that explains *why* each technology was chosen, not just *what* it is. This prevents your agent from suggesting alternatives you've already considered and rejected.

> **Tip:** The decision-making framework is the most valuable part. Questions like "Does it work on a single VPS?" act as architectural guardrails that your agent will reference in every future conversation.

---

### Step 3 — Expert Panel (EXPERTS.md)

Define specialized personas that your LLM agent can adopt for domain-specific guidance. Think of it as assembling your virtual advisory board.

**What to include:**
- 8-12 expert roles covering all project domains
- For each: specialty, deep knowledge areas, thinking patterns, when to consult, a characteristic quote
- A composition table mapping decisions to recommended expert combinations

**How to prompt your agent:**
```
"Create an EXPERTS.md with specialized expert personas for this project.
I need experts covering: [backend architecture, API design, security,
DevOps, UX, product strategy, etc.]. Each should have a distinct
perspective and a characteristic voice."
```

**How to use later:**
```
"Act as the Security Engineer and review this authentication flow."
"I need the API Architect and the DX Engineer to discuss this endpoint naming."
"Convene a panel of Email Infrastructure + Security + DevOps to review the SMTP design."
```

> **Tip:** The panel composition table at the bottom of EXPERTS.md is critical. When facing a cross-cutting decision, you don't want to guess which experts to involve — the table tells you.

> **Tip:** Give each expert a characteristic "would say" quote. This anchors the persona and makes the agent's responses noticeably different when adopting each role.

> **Tip:** Include a "Product Manager" expert who thinks about scope, adoption, and competitive positioning. This voice helps you resist feature creep.

---

### Step 4 — Roadmap (ROADMAP.md)

Break the project into phases with clear exit criteria. This prevents scope creep and gives your agent context about what's important *now* vs *later*.

**What to include:**
- Current state assessment
- 5-8 phases from foundation to post-MVP
- Each phase: description, task list, exit criteria
- Milestones summary showing what each phase unlocks
- Feature evolution paths (how capabilities grow across phases)

**How to prompt your agent:**
```
"Help me create a phased roadmap for this project. Phase 0 is infrastructure.
The MVP needs [core features]. The key differentiator is [feature X].
Each phase should have clear exit criteria. Include a milestone summary."
```

**Key principle:** Exit criteria are concrete and testable — "Send an email via swaks, verify it's in PostgreSQL" not "SMTP works."

> **Tip:** Define milestones that unlock real usage. "Internal Alpha" = you can use it yourself. "Dogfood Ready" = you use it daily. "Differentiator" = the unique feature is live. These milestones give you motivation and direction.

> **Tip:** Include a "Post-MVP Features" phase with a prioritized table. This gives you a place to put good ideas without derailing current work. When someone (or your agent) suggests a feature, you can say "that's Phase 7" instead of debating it.

> **Tip:** Feature evolution paths (like Inboxed's SMTP levels 1→2→3) help your agent understand that some capabilities are designed to grow. The data model can be prepared for future phases without building them now.

---

### Step 5 — Branding (BRANDING.md)

Define the visual identity before building any UI. This ensures consistency from the first component.

**What to include:**
- Product name, tagline variations, voice & tone
- Color palette with CSS variables (Tailwind v4 `@theme` format)
- Typography system (display, body, mono, accent fonts)
- Logo concept and SVG source
- UI patterns (terminal windows, badges, inbox rows, animations)
- Landing page structure
- Inspiration references

**How to prompt your agent:**
```
"Create a branding guide for [project name]. The aesthetic is [describe it —
e.g., 'retro terminal meets modern dev tool']. Include a full color palette
as Tailwind v4 CSS variables, typography system, logo concept as SVG,
and UI component patterns. Reference [tools you admire] for inspiration."
```

**Why before code:** Every component you build will reference BRANDING.md. Defining it early means no visual inconsistencies to fix later.

> **Tip:** Use AI chat tools to generate and iterate on visual concepts. Describe your aesthetic, get feedback, refine. Then bring the final direction to your coding agent for the technical implementation (CSS variables, SVGs, component patterns).

> **Tip:** Include a "Voice & Tone" section with do/don't examples. This shapes not just UI copy but also error messages, documentation, and even commit messages.

> **Tip:** Define UI patterns as text/ASCII mockups (like the terminal window, inbox row, badge styles in Inboxed's BRANDING.md). Your agent can reference these directly when building components, giving you consistent results without a Figma file.

---

### Step 6 — Agent Instructions (AGENTS.md + tool-specific config)

Create the files that shape every future LLM agent interaction with your project. Most coding agents support a project-level instruction file that's automatically loaded:

| Tool | Config file | Auto-loaded? |
|------|------------|-------------|
| Claude Code | `CLAUDE.md` | Yes |
| Cursor | `.cursorrules` | Yes |
| Windsurf | `.windsurfrules` | Yes |
| Copilot | `.github/copilot-instructions.md` | Yes |
| Aider | `.aider.conf.yml` | Yes |
| Generic | `AGENTS.md` | Reference manually |

**Tool-specific config** — keep it minimal, just a pointer:
```markdown
# Instructions
Read [AGENTS.md](AGENTS.md) before starting any task.
```

**AGENTS.md** — the real content (tool-agnostic, works everywhere):
- What the project is (one paragraph)
- Tech stack table
- Repository structure (keep updated as it evolves)
- Links to all documentation with "when to read" guidance
- Code style rules per language
- Architecture layer rules (where code goes)
- Behavioral guidelines for writing code and making decisions

**How to prompt your agent:**
```
"Create AGENTS.md with instructions for AI agents working in this codebase.
Include the tech stack, repo structure, links to all docs in docs/,
code style rules, and guidelines for architectural decisions.
Also create the tool-specific config file that points to it."
```

**Key principle:** AGENTS.md is a living document. Update it every time your architecture evolves — after specs, after ADRs, after major implementation changes.

> **Tip:** The "When to read" table is a multiplier. Instead of your agent reading every document on every task, it reads the relevant ones. This keeps context focused and responses precise.

> **Tip:** After Step 8 (Architecture), come back and add the layer rules ("where code goes" table) to AGENTS.md. This is the single most impactful thing for code generation quality — your agent will put domain logic in the domain layer, not in controllers.

> **Tip:** Keep the tool-specific config file minimal — just a pointer to AGENTS.md. Your agent reads it automatically on every conversation, so it should be light. The heavy content goes in AGENTS.md, which is tool-agnostic and version-controlled alongside your code.

---

### Step 7 — Foundation Spec & Implementation (specs/000)

Write the first implementation spec — bootstrap the technical stack. Then implement it.

**What to include in the spec:**
- What's being built (scope boundary)
- Service definitions (each app: what it does, tech, entry points)
- Infrastructure config (Docker, ports, environment variables)
- Authentication strategy
- CORS / cross-service communication
- File-by-file implementation plan
- Verification steps

**How to prompt your agent:**
```
"Write a foundation spec for bootstrapping the project. We need:
- [Service A]: [framework], [purpose]
- [Service B]: [framework], [purpose]
Include Docker setup, auth strategy, CORS config, and a step-by-step
implementation plan with file paths. This is spec 000."
```

**Then implement it:**
```
"Implement the foundation spec (docs/specs/000-foundation.md).
Start with [Service A], then [Service B]. Follow the spec exactly."
```

**Commit pattern:** One commit per service/concern:
- `feat: add Rails 8 API-only app with dual auth strategy`
- `feat: add Svelte 5 dashboard with dark terminal theme`
- `feat: add MCP server skeleton with TypeScript`
- `chore: update infrastructure for three-service architecture`

> **Tip:** Write the spec *before* implementing. The spec is your contract with your agent. When you say "follow the spec exactly," the agent has a precise blueprint — file paths, patterns, configuration values. The output quality is dramatically higher than freeform prompting.

> **Tip:** Specs should include verification steps. For the foundation: "Run `bin/rails server`, verify the status endpoint returns 200. Run `npm run dev`, verify Vite starts. Run `npm run build`, verify TypeScript compiles."

> **Tip:** Review the spec before implementing. Read it, challenge assumptions, adjust. It's much cheaper to change a document than to refactor generated code.

---

### Step 8 — Architecture Spec & ADRs (specs/001 + adrs/)

Once the foundation is running, formalize the architecture and record decisions. This is where the project transitions from "scaffolded" to "well-engineered."

**Architecture spec (specs/001-architecture.md):**
- Layer definitions (domain, application, infrastructure, presentation)
- Directory conventions per layer
- Dependency rules (what can import what)
- Patterns per service (DDD for API, feature-based for dashboard, hexagonal for MCP)
- Testing conventions per layer
- Event system design (if applicable)

**Architecture Decision Records (docs/adrs/):**
- One file per significant decision
- Format: Context → Decision → Consequences
- Number sequentially: `001-rich-ddd.md`, `002-custom-event-store.md`, etc.

**How to prompt your agent:**
```
"Write an architecture spec for the project. The API uses [pattern],
the dashboard uses [pattern], the MCP server uses [pattern].
Define layer rules, directory conventions, and testing strategy.

Then create ADRs for the key decisions:
- Why [pattern X] over [pattern Y]
- Why [library A] for [purpose]
- Why [architectural choice]"
```

**After creating specs/ADRs, update AGENTS.md** with the architecture layer rules so future conversations respect them.

> **Tip:** ADRs are one of the highest-value artifacts you can create. They prevent revisiting decisions. When future-you (or your agent) questions "why DDD instead of plain Rails?", the ADR has the context, alternatives considered, and consequences accepted. Without ADRs, you'll re-debate the same decisions repeatedly.

> **Tip:** Every ADR should have a "Context" section that captures *why* the decision was needed, not just what was decided. Context decays fast — in 3 months you won't remember why you were choosing between two approaches unless it's written down.

> **Tip:** Use experts from EXPERTS.md when writing the architecture spec. "Act as the Full-Stack Engineer and the Security Engineer to design the authentication layer." This produces more thoughtful output than generic prompting.

> **Tip:** The dependency rules matter more than the directory structure. "Domain layer has zero Rails dependencies" is a rule that prevents the most common architecture erosion. Make these rules explicit and add them to AGENTS.md.

---

### Step 9 — Deploy Strategy (Kamal, Docker, CI)

Define how the project gets from development to production. Set this up early — not as an afterthought after "the code is done."

**Why early:**
- Dockerfiles written during scaffolding stay current (not retrofitted later)
- CI catches issues from the first commit
- Kamal/deploy config shapes how services communicate (internal networking, env vars)
- You can deploy a skeleton app to verify the pipeline works before there's complex code

**What to set up:**

| Concern | Files | Purpose |
|---------|-------|---------|
| Production Docker | `apps/*/Dockerfile` | Multi-stage builds per service |
| Orchestration | `docker-compose.yml` | Self-hosting stack (all services + databases) |
| Deploy | `config/deploy.yml` | Kamal configuration (servers, registry, accessories) |
| CI/CD | `.github/workflows/ci.yml` | Test + build + push Docker images |
| Env config | `.env.example` | All variables documented |

**Kamal configuration essentials:**
```yaml
# Primary service (Rails API)
service: inboxed
proxy:
  ssl: true
  host: your.domain.com
  app_port: 3000

# Accessories (Dashboard, MCP, databases)
accessories:
  dashboard:
    image: ghcr.io/you/dashboard
    port: "80:80"
  mcp:
    image: ghcr.io/you/mcp
    port: "3001:3001"
```

**How to prompt your agent:**
```
"Set up the deploy infrastructure:
1. Production docker-compose.yml with all services (API, Dashboard, MCP,
   PostgreSQL, Redis) using env vars for configuration
2. Kamal deploy.yml with the API as primary, Dashboard and MCP as accessories
3. Multi-stage Dockerfiles for each service (small final images)
4. .env.example documenting all required variables"
```

> **Tip:** Keep the production `docker-compose.yml` separate from the devcontainer one. They serve different purposes — dev has hot-reload, debug tools, exposed ports. Production has minimal images, healthchecks, restart policies.

> **Tip:** Use env vars with defaults for all ports in `docker-compose.yml`: `"${INBOXED_API_PORT:-3000}:3000"`. This lets users customize host ports without editing the compose file.

> **Tip:** Set up Kamal even before your first deploy. The `deploy.yml` file documents your production topology — what services exist, how they connect, what env vars are needed. It's documentation that happens to be executable.

> **Tip:** Write Dockerfiles during the foundation spec (Step 7), not as a separate step. When your agent generates a Rails app, ask it to include the Dockerfile. This way the Dockerfile evolves with the app, not as a bolted-on afterthought.

---

### Step 10 — Dev Workflow Setup

Make the project pleasant to work in day-to-day.

**What to set up:**
- Process manager (`Procfile.dev` + `bin/dev` with Foreman) to start all services with one command
- Shell aliases for common commands (`rs`, `rc`, `ds`, `mcp`, `dev`)
- Linters and formatters per language (StandardRB, ESLint, Prettier)
- Git hooks (optional: pre-commit for linting)

**How to prompt your agent:**
```
"Set up a dev workflow: Foreman with Procfile.dev to run all services,
shell aliases in post-install.sh, and a bin/dev script.
Use non-default ports to avoid collisions with other projects."
```

> **Tip:** The `bin/dev` script should auto-install foreman if it's missing. One less thing for contributors to figure out.

> **Tip:** Non-default ports are worth the tiny initial confusion. If you're working on multiple projects, port collisions are a constant annoyance. Pick a port range (3100-3199) and own it.

> **Tip:** Add shell aliases to `post-install.sh`, not to the Dockerfile. Aliases are personal workflow — they should be easy to customize without rebuilding the container.

---

### Step 11 — Supporting Documents

Round out the documentation with operational files:

| Document | Purpose | When to create |
|----------|---------|---------------|
| `CONTRIBUTING.md` | Code style, PR process, commit conventions | Before any external contributor |
| `SECURITY.md` | Vulnerability disclosure, threat model | Before any public release |
| `CHANGELOG.md` | Release notes template | Before first tagged release |
| `.env.example` | All configuration with comments | When env vars are finalized |

---

## Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/) throughout:

| Prefix | When |
|--------|------|
| `feat:` | New feature or capability |
| `fix:` | Bug fix |
| `docs:` | Documentation only |
| `chore:` | Tooling, config, infrastructure |
| `refactor:` | Code change that doesn't add features or fix bugs |
| `test:` | Adding or updating tests |

---

## Quick Reference: Prompts That Work

### For research and ideation
```
"Research the landscape of [domain]. What tools exist, what are their
architectures, and where are the gaps?"

"Help me define the MVP for [project]. The core problem is [X].
What are the must-haves vs nice-to-haves?"
```

### For documentation
```
"Create [DOCUMENT].md for this project. Here's the context: [context].
Follow the pattern from [existing doc] but adapted for [this purpose]."
```

### For specs
```
"Write implementation spec [number] for [feature]. Include:
scope, technical approach, file-by-file plan, and verification steps.
Reference the architecture from spec 001."
```

### For implementation
```
"Implement spec [number]. Follow the spec exactly. Start with [component]."
```

### For architecture decisions
```
"I need to decide between [option A] and [option B] for [purpose].
Act as the [relevant expert] and give me your recommendation with tradeoffs.
Then write an ADR documenting the decision."
```

### For expert consultation
```
"Convene the [Expert 1] and [Expert 2] to review [this design/code/decision].
I want to hear both perspectives before deciding."
```

### For deploy and infrastructure
```
"Set up Kamal deployment for this project. The API is the primary service,
[Dashboard] and [MCP] are accessories. Target a single VPS with PostgreSQL
and Redis as Kamal accessories."
```

---

## The Build Path (Summary)

```
 0. Research       → Competitive analysis, domain knowledge, refine scope
 1. DevContainer   → Reproducible dev environment with all services
 2. Identity       → IDENTITY.md — who's building, how they decide
 3. Experts        → EXPERTS.md — virtual advisory board
 4. Roadmap        → ROADMAP.md — phases with exit criteria
 5. Branding       → BRANDING.md — colors, typography, UI patterns
 6. Agent config   → AGENTS.md + tool config — shape AI interactions
 7. Foundation     → Spec 000 — bootstrap the stack, implement it
 8. Architecture   → Spec 001 + ADRs — formalize patterns and decisions
 9. Deploy         → Kamal, Docker, CI/CD — production pipeline early
10. Dev workflow   → Foreman, aliases, linters — pleasant daily experience
11. Docs           → CONTRIBUTING, SECURITY, CHANGELOG, .env.example
```

Each step builds on the previous. Skip a step and you'll feel the gap in every future conversation — your agent will give less precise answers, architecture will drift, and decisions won't be recorded.

---

## Multipliers: Things That 10x the Workflow

These are patterns that compound in value across the entire project:

### 1. ADRs for every non-obvious decision
If you debated it for more than 5 minutes, write an ADR. Future-you will thank you. Future agent sessions will produce better code because the reasoning is accessible.

### 2. Specs before implementation
The act of writing a spec forces you to think through edge cases, file structures, and integration points *before* writing code. An agent with a spec generates dramatically better code than an agent with a vague prompt.

### 3. AGENTS.md as living architecture docs
Every time you add a layer rule, a pattern, or a convention to AGENTS.md, every future agent conversation inherits that knowledge. This compounds — by month 3, your agent understands your project better than most human collaborators would.

### 4. Expert personas for cross-cutting decisions
Instead of asking "what should the auth flow look like?", ask "Act as the Security Engineer and the API Architect and debate this auth flow." The quality difference is significant — you get domain-specific reasoning instead of generic best practices.

### 5. Verification steps in every spec
"Verify by running X and seeing Y" is the difference between a spec that's done and a spec that's "probably done." It also gives you natural commit points.

### 6. Research before decisions
30 minutes of research with an AI tool can save days of wrong-direction implementation. Understand the landscape before committing to an approach.

### 7. Non-default ports from day one
Trivial decision, saves hours of debugging port collisions across projects over the lifetime of the project.

### 8. Separate dev and production configs
DevContainer compose != production compose. Dev has hot-reload, debug ports, verbose logging. Production has minimal images, healthchecks, restart policies. Mixing them creates fragile configurations.

---

## Adapting This Workflow

This workflow was designed for a solo developer building a developer tool. To adapt:

- **Team project:** Add team member profiles to IDENTITY.md, expand CONTRIBUTING.md with review process
- **Client project:** Replace IDENTITY.md focus from "who's building" to "who's the client and what are their constraints"
- **Simpler project:** Skip EXPERTS.md and ADRs, keep everything else
- **Larger project:** Add `docs/rfcs/` for design proposals, expand specs with acceptance criteria

The minimum viable workflow is: **DevContainer → AGENTS.md → Roadmap → Spec 000 → Implement.** Everything else makes it better but isn't strictly required.
