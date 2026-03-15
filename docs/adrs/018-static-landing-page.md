# ADR-018: Static Landing Page with Tailwind

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

Inboxed needs a public-facing page for the open-source launch — a place to communicate what it is, why it matters, and how to get started. This is the first thing potential users and GitHub visitors see.

### Options Considered

**A: No landing page — README only**
- Pro: Zero maintenance
- Con: README is limited in visual impact, no SEO, no shareable URL beyond GitHub

**B: Static HTML + Tailwind CSS in `site/`, deploy to GitHub Pages**
- Pro: Zero runtime dependencies, loads in <1s, free hosting
- Pro: Follows BRANDING.md design language (dark theme, phosphor green, terminal aesthetic)
- Pro: Lives in the monorepo, versioned with the project
- Con: Manual HTML editing (no CMS)

**C: Docs site framework (Docusaurus, Astro, VitePress)**
- Pro: Markdown-based content, sidebar navigation, search
- Con: Build step, framework dependencies, more infrastructure than needed
- Con: A docs framework for a single-page landing is overkill

**D: Separate marketing site (Framer, Webflow)**
- Pro: Visual editor, fast iteration
- Con: External dependency, paid tool, not in the repo
- Con: Inconsistent with the self-hosted, open-source ethos

## Decision

**Option B** — a single static HTML page with Tailwind CSS, living in `site/` within the monorepo, deployed to GitHub Pages.

### Rationale

- The landing page is a **single page**, not a docs site. HTML + Tailwind is the right tool for a single page.
- BRANDING.md already defines the full design: colors, typography, layout structure, tone. No design decisions to make.
- GitHub Pages is free, fast, and automatic. A GitHub Action builds and deploys on push to `main`.
- The audience is developers. A fast, clean, no-JavaScript page earns more respect than a heavy SPA.

### Page Structure (from BRANDING.md)

```
HERO
  [@] inboxed
  "Your emails go nowhere. You see everything."
  [Get Started →] [View on GitHub →]

FEATURES (3 columns)
  [@ Catch]     — SMTP server catches all test emails
  [~ Inspect]   — Dashboard, REST API, real-time updates
  [⚡ Assert]   — MCP server, client libraries, zero sleeps

QUICKSTART
  Terminal-style block with 3 commands:
  $ git clone ... && cd inboxed
  $ bin/setup
  $ docker compose up -d

MCP HIGHLIGHT
  "The first email dev server with native AI agent integration"
  Code example: Claude extracts OTP without leaving the conversation

FOOTER
  [@] inboxed · GitHub · MIT License · notdefined.dev
```

### Technical Details

- **Build:** Tailwind CLI (standalone binary, no Node required for CI)
- **Fonts:** Space Grotesk (display), JetBrains Mono (code), Inter (body) — loaded from Google Fonts or self-hosted
- **No JavaScript** — pure HTML + CSS. Animated terminal demo uses CSS keyframes only.
- **Responsive:** Mobile-first, single breakpoint at `md` (768px)
- **Dark only:** Dev tool audience, dark theme per BRANDING.md

## Consequences

### Easier

- **Fast** — loads in <500ms, no JS bundle, no hydration
- **Free hosting** — GitHub Pages, zero cost
- **Versioned** — lives in repo, changes tracked in git
- **Simple to update** — edit HTML, push, deployed

### Harder

- **No CMS** — content changes require code edits (acceptable for a dev tool)
- **No search** — single page doesn't need it
- **No i18n** — English only (acceptable scope)

### Mitigations

- If the project grows enough to need a docs site, migrate to Astro/VitePress later
- The landing page links to `docs/guides/` in the repo for detailed documentation
