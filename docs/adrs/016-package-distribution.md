# ADR-016: Client Library Distribution

**Status:** accepted
**Date:** 2026-03-15
**Deciders:** Project owner

## Context

Inboxed ships two lightweight client libraries: `inboxed` (TypeScript/npm) and `inboxed` (Ruby gem). Both live in the monorepo. We need to decide where they live and how they're distributed.

### Options Considered

**A: Separate repositories per client**
- Pro: Clean git history, independent CI
- Con: Splits the monorepo, harder to keep in sync with API changes

**B: Monorepo under `packages/`, publish to registries**
- Pro: Everything in one place, single CI
- Pro: API spec changes can update both clients in one PR
- Con: Publishing overhead (versioning, registry auth, release process)

**C: Monorepo under `packages/`, install from git (no registry publishing)**
- Pro: Zero publishing overhead
- Pro: Always in sync with the API
- Con: Slightly more friction to install (`npm install github:...` instead of `npm install inboxed`)
- Con: No semantic versioning visible in registries

**D: Monorepo under `packages/`, publish to registries later when there's demand**
- Pro: Start with git install, add registry publishing when adoption warrants it
- Pro: No premature process overhead
- Con: Initial users have a slightly rougher install experience

## Decision

**Option D** — client libraries live in `packages/` within the monorepo. Initially installable from source/git. Publish to npm and RubyGems when there's community demand.

### Directory Structure

```
packages/
├── typescript/                  # inboxed (npm)
│   ├── package.json
│   ├── tsconfig.json
│   ├── src/
│   │   ├── index.ts             # Public exports
│   │   ├── client.ts            # InboxedClient class
│   │   ├── extract.ts           # Extraction helpers
│   │   ├── errors.ts            # Typed errors
│   │   └── types.ts             # Email, Inbox interfaces
│   └── __tests__/
└── ruby/                        # inboxed (gem)
    ├── inboxed.gemspec
    ├── lib/
    │   ├── inboxed.rb           # Top-level module + config
    │   └── inboxed/
    │       ├── client.rb
    │       ├── extract.rb
    │       ├── errors.rb
    │       └── email.rb
    └── spec/
```

### Installation (Initial)

```bash
# TypeScript — install from local path or git
npm install ../packages/typescript    # local monorepo
npm install github:user/inboxed#main  # from git

# Ruby — install from local path or git
gem "inboxed", path: "../packages/ruby"     # local
gem "inboxed", git: "https://github.com/user/inboxed", glob: "packages/ruby/*.gemspec"
```

### Publishing (When Demand Warrants)

```bash
# npm
cd packages/typescript && npm publish

# RubyGems
cd packages/ruby && gem build && gem push inboxed-*.gem
```

## Consequences

### Easier

- **Zero publishing overhead** initially — no registry auth, no release process
- **Always in sync** — clients evolve with the API in the same repo
- **Simple CI** — one pipeline tests everything
- **Low commitment** — if the client API changes, no published versions to support

### Harder

- **Install friction** — git-based install is less familiar than `npm install inboxed`
- **No discoverability** — users won't find the package on npm/rubygems search

### Mitigations

- README docs include exact install commands for both methods
- Publishing to registries is a single command when the time comes
- The self-hosted audience is comfortable with git-based installs

### Revisit When

- More than 5 external users request registry publishing
- Inboxed gets a public launch and discoverability matters
