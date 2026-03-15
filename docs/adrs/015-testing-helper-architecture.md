# ADR-015: Lightweight Client Libraries over Framework-Specific SDKs

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

Inboxed needs to be consumable from automated tests. The original plan was framework-specific SDKs: a Playwright fixture (`@inboxed/playwright`) and an RSpec gem (`inboxed-rspec`) with custom matchers.

After expert panel review, we questioned: **does a self-hosted dev tool need published framework-specific SDKs, or is there a simpler approach?**

### Options Considered

**A: Framework-specific SDKs (Playwright fixture, RSpec matchers)**
- Pro: Best-in-class DX for those two frameworks
- Con: Maintenance burden — versioning, publishing, compatibility across framework versions
- Con: Only covers two frameworks. Cypress, Pytest, Vitest, Minitest users get nothing
- Con: Self-hosted tool with small audience — the ROI of published packages is low
- Con: Playwright fixtures and RSpec matchers are thin wrappers (~20 lines each) over the real value: the API client + extraction

**B: Lightweight API client libraries (TypeScript + Ruby) + integration guides**
- Pro: The client works with any framework in that language — Playwright, Vitest, Jest, Cypress, RSpec, Minitest, etc.
- Pro: Framework-specific patterns are documented as examples, not maintained as code
- Pro: Much less maintenance burden — no framework version compatibility to track
- Pro: Users who know their framework can wire it up in minutes
- Con: Slightly more setup than a pre-built fixture

**C: No client libraries — just REST API docs + code examples**
- Pro: Zero code to maintain
- Con: Every user reimplements auth, wait logic, and extraction from scratch
- Con: The wait + extraction pattern is non-trivial enough to warrant a client

## Decision

**Option B** — ship lightweight API client libraries in TypeScript and Ruby, with documented integration patterns for popular frameworks.

### Rationale

- **The REST API is the universal integration.** Any language with HTTP can use Inboxed. Client libraries add convenience, not capability.
- **90% of the value is in the client + extraction helpers.** A Playwright fixture is 15 lines over the client. RSpec matchers are 20 lines. These belong in docs, not in a maintained package.
- **Self-hosted = technical audience.** Users who self-host Inboxed can wire a client into their test framework. They don't need hand-holding.
- **Fewer packages = less maintenance.** No framework version compatibility, no publishing pipelines, no issue triage for "doesn't work with Playwright 1.48".
- **More frameworks covered.** By not coupling to Playwright/RSpec, the same client works with Vitest, Jest, Cypress, Minitest, Pytest (via the TypeScript or Ruby client), or any HTTP client.

### Design Principles

1. **Client, not SDK** — the libraries are HTTP clients with extraction helpers, not framework integrations
2. **Framework-agnostic** — works with any test runner in that language
3. **Configuration via environment** — `INBOXED_API_URL` and `INBOXED_API_KEY` env vars, with explicit config option
4. **Extraction parity** — both clients implement identical extraction logic (spec 005, section 4.4-4.6)
5. **Deterministic** — clients use `POST /api/v1/emails/wait` long-poll. No `sleep()`, no polling loops
6. **Integration guides, not wrappers** — docs show how to use the client from Playwright, RSpec, Vitest, Cypress, etc.

## Consequences

### Easier

- **Universal** — works with any test framework in TypeScript or Ruby
- **Low maintenance** — no framework coupling, no version matrix
- **Simple testing** — mock HTTP, test extraction as pure functions
- **Docs-driven integration** — adding a new framework guide is a README section, not a new package

### Harder

- **Slightly more setup** — user writes 5-10 lines of glue code instead of importing a fixture
- **No auto-discovery** — user won't find `@inboxed/playwright` on npm (mitigated by docs)

### Mitigations

- Integration guides include copy-pasteable code for each framework
- The client API is simple enough that wiring into any framework takes <5 minutes
- If demand grows for a specific framework, we can publish a thin wrapper later (YAGNI until then)

### Revisit When

- A specific framework integration gets requested repeatedly by the community
- Inboxed adoption grows enough that the maintenance cost of published SDKs is justified
