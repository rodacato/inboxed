# Inboxed — Specs

> Implementation specs for each unit of work. Each spec is the plan we agree on before writing code.

---

## Process

1. **Draft** — Create the spec with objective, context, plan, decisions, and exit criteria
2. **Review** — Discuss, challenge, refine. Use the [Expert Panel](../EXPERTS.md) for domain-specific input
3. **Approved** — Spec is locked. This is what we build
4. **In Progress** — Implementation underway
5. **Done** — Exit criteria met, code merged, release tagged

A spec can be updated after approval if scope changes — mark the change with a `> **Updated YYYY-MM-DD:** reason` block at the top.

---

## Naming Convention

```
NNN-short-slug.md
```

- `NNN` — sequential number, zero-padded to 3 digits
- `short-slug` — lowercase, hyphen-separated, descriptive
- Numbers are sequential across the whole project, not tied to roadmap phases
- One spec can cover a full phase or a subset of it

Examples:
```
000-project-foundation.md
001-smtp-reception.md
002-data-models.md
003-rest-api.md
```

---

## Spec Template

Each spec follows this structure:

```markdown
# NNN — Title

> One-line summary of what this spec covers.

**Phase:** [Roadmap phase reference]
**Status:** draft | approved | in progress | done
**Release:** — (filled when shipped)

---

## Objective

What we're building and why it matters.

## Context

Current state, constraints, relevant background.

## Implementation Plan

Ordered steps to execute. Concrete enough to follow.

## Technical Decisions

For each significant choice:

### Decision: [Title]

- **Options considered:** A, B, C
- **Chosen:** B
- **Why:** Justification
- **Trade-offs:** What we're giving up

## Exit Criteria

How we know this spec is done. Testable, specific.

## Open Questions

Unresolved items to discuss before moving to approved.
```

---

## Index

| # | Spec | Phase | Status | Release | Abstract |
|---|------|-------|--------|---------|----------|
| 000 | [Project Foundation](000-foundation.md) | Phase 0 | draft | — | Rails API-only + Svelte SPA + MCP skeleton + Caddy proxy + CI/CD + Kamal deploy. Infrastructure validated end-to-end, no business logic. |

<!--
Template row:
| 000 | [Project Foundation](000-project-foundation.md) | Phase 0 | draft | — | Bootstrap Rails app, configure devcontainer services, establish project structure |
-->
