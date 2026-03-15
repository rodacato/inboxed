# ADR-019: Docker Compose as Primary Deployment Path

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

Inboxed targets solo developers and small teams running on a single VPS. Two deployment tools are available: Docker Compose (simple, declarative) and Kamal (Rails-native, zero-downtime deploys). We need to decide which is the **primary documented path**.

### Options Considered

**A: Kamal as primary, Docker Compose as fallback**
- Pro: Zero-downtime deploys, rolling restarts, built into Rails 8
- Con: Requires SSH key setup, registry auth, server provisioning
- Con: Steeper learning curve — Kamal has its own concepts (accessories, proxies, roles)
- Con: Overkill for a dev tool on a single VPS

**B: Docker Compose as primary, Kamal documented for advanced users**
- Pro: Universally understood — every developer knows `docker compose up`
- Pro: Zero external dependencies beyond Docker
- Pro: Single file defines the entire stack
- Pro: Matches the exit criteria: "git clone to receiving emails in 10 minutes"
- Con: No zero-downtime deploys (acceptable for a dev tool)

**C: Both equally documented**
- Pro: Users choose their preference
- Con: Doubles the documentation surface, confuses newcomers about the "right" way

## Decision

**Option B** — Docker Compose is the primary and recommended deployment method. Kamal is documented as an optional advanced path for teams that want zero-downtime deploys.

### Rationale

- **10-minute goal:** `docker compose up -d` is the fastest path from clone to running. Kamal adds ~20 minutes of setup (SSH keys, registry, server config).
- **Target audience:** Solo developers on a VPS. They don't need rolling deploys for a testing tool.
- **Cognitive load:** One "blessed" path reduces confusion. The quickstart says "run these 3 commands", not "choose between two deployment strategies".
- **Kamal remains available:** `config/deploy.yml` already exists. Teams that want Kamal can use it — it's documented in `docs/guides/kamal-deploy.md`, just not the primary path.

### Upgrade Path

```
Level 1: docker compose up -d (primary — most users stop here)
Level 2: Kamal deploy (optional — zero-downtime, multi-server)
Level 3: Kubernetes (out of scope — not documented, not supported)
```

## Consequences

### Easier

- **Quickstart is 3 commands:** clone, setup, docker compose up
- **No external dependencies:** no registry auth, no SSH keys, no Kamal gem
- **Portable:** works on any machine with Docker installed
- **Debuggable:** `docker compose logs` shows everything

### Harder

- **No zero-downtime deploys** — `docker compose up -d` restarts containers (brief downtime)
- **Manual updates** — `git pull && docker compose up -d --build` (no auto-deploy)

### Mitigations

- Brief downtime is acceptable for a dev/testing tool — nobody's production depends on it
- Document the update process in `docs/guides/upgrading.md`
- Kamal guide available for teams that need more
