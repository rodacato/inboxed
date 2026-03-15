# ADR-017: Interactive Setup Script with Secure Defaults

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

Self-hosted tools live or die by the first-run experience. Inboxed requires several secrets (`SECRET_KEY_BASE`, `INBOXED_ADMIN_TOKEN`, `POSTGRES_PASSWORD`) and configuration values (`INBOXED_DOMAIN`) to start. If a user has to manually generate secrets and edit `.env` files, they'll make mistakes — or worse, leave insecure defaults like "changeme".

### Options Considered

**A: Manual `.env` setup (copy `.env.example`, edit values)**
- Pro: Simplest to implement
- Con: Users forget to generate secrets, leave insecure defaults
- Con: More than 3 steps to first run — breaks the "10 minute" goal

**B: Interactive `bin/setup` script that generates secrets and `.env`**
- Pro: One command, asks only what it can't guess (domain), generates everything else
- Pro: Secrets are cryptographically random by default — no "changeme"
- Pro: Validates prerequisites (Docker, docker compose) before proceeding
- Con: Shell script maintenance

**C: Docker-based setup (generate secrets at container start)**
- Pro: No host dependencies beyond Docker
- Con: Secrets visible in container logs or environment
- Con: Harder to customize before first run

## Decision

**Option B** — an interactive `bin/setup` script that generates a complete `.env` file with secure defaults.

### Script Behavior

```bash
$ bin/setup

  [@] Inboxed Setup
  ─────────────────

  Checking prerequisites...
  ✓ Docker 27.1.0
  ✓ Docker Compose v2.29.0

  Configuration:
  Domain [localhost]: mail.example.com
  Dashboard port [80]:
  SMTP port [587]:

  Generating secrets...
  ✓ SECRET_KEY_BASE (64 bytes)
  ✓ INBOXED_ADMIN_TOKEN (32 bytes)
  ✓ POSTGRES_PASSWORD (32 bytes)

  ✓ .env written

  Next steps:
    docker compose up -d
    open http://localhost (or http://mail.example.com)
```

### Secure Defaults

1. **All secrets auto-generated** — `openssl rand -hex` for each secret. Never prompt the user to type a password.
2. **SMTP ports internal only** — `docker-compose.yml` binds SMTP to `127.0.0.1` by default. User must explicitly open to network.
3. **Admin token required** — setup generates it; dashboard won't start without it.
4. **`.env` not committed** — already in `.gitignore`.

### Prerequisites Check

The script validates before proceeding:
- Docker installed and running
- Docker Compose v2 available
- Ports 80, 587, 5432 not already in use (warn, don't block)

## Consequences

### Easier

- **One command to configure** — `bin/setup` then `docker compose up -d`
- **Secure by default** — no user-generated secrets, no insecure placeholders
- **Idempotent** — running again detects existing `.env` and asks to overwrite or keep

### Harder

- **Shell script maintenance** — but the script is ~100 lines, not a framework
- **Platform differences** — `openssl` availability on Windows (mitigated: targets Linux/macOS VPS)

### Mitigations

- Script uses only POSIX shell + `openssl` (available on all target platforms)
- Windows users can use WSL or manually copy `.env.example`
- Script is optional — advanced users can still edit `.env` manually
