# 000 — Project Foundation

> Bootstrap the monorepo with Rails API, Svelte dashboard, MCP server, Caddy proxy, CI/CD pipeline, and Kamal deploy — validated end-to-end before writing any business logic.

**Phase:** Phase 0 (Foundation)
**Status:** implemented
**Release:** —

---

## Objective

Validate the full stack and deployment pipeline before writing a single line of business logic. By the end of this spec, a `git push` to `main` triggers CI, builds Docker images, and Kamal deploys everything to the VPS. The dashboard loads with the Inboxed branding, and the API responds at `/api/v1/status`.

No models, no SMTP, no email logic. Just infrastructure that works.

---

## Context

### Current State
- Monorepo exists with empty `apps/web/` and `apps/mcp/` directories
- Devcontainer configured: Ruby 3.3, Node 22, PostgreSQL 16, Redis 7
- Kamal deploy config exists at `config/deploy.yml` (template, needs updates)
- Branding guide defined in `docs/BRANDING.md`
- UI mockups available in `docs/screens/` (Stitch-generated)
- No application code yet

### Constraints
- Self-hosted on Hetzner VPS via Kamal
- Must work with `docker compose up` for local dev
- Dashboard is a separate Svelte SPA served by Caddy (not embedded in Rails)
- API-first: the API is the primary interface, dashboard is a client

---

## Monorepo Structure

```
inboxed/
├── apps/
│   ├── api/              # Rails 8 API-only
│   ├── dashboard/        # Svelte 5 SPA + Tailwind 4
│   └── mcp/              # Node.js MCP server (TypeScript)
├── config/
│   └── deploy.yml        # Kamal configuration
├── .devcontainer/        # Dev environment (exists)
├── .github/
│   └── workflows/
│       └── ci.yml        # GitHub Actions CI
├── docker-compose.yml    # Production / self-hosting
├── Caddyfile             # Caddy reverse proxy config
└── docs/
```

### Decision: Rename `apps/web/` to `apps/api/`

- **Options:** Keep `apps/web/`, rename to `apps/api/`
- **Chosen:** Rename to `apps/api/`
- **Why:** The Rails app is API-only. Calling it `web` implies it serves HTML. `api` makes the architecture intent clear to every contributor.
- **Trade-offs:** Need to update `config/deploy.yml` builder path and devcontainer references.

---

## Implementation Plan

### 1. Rails API-Only App (`apps/api/`)

```bash
cd apps/api
rails new . --api --database=postgresql --skip-test --skip-system-test --skip-action-mailbox --skip-action-text --skip-active-storage
```

#### 1.1 Database Configuration

Configure `config/database.yml` for devcontainer:

```yaml
default: &default
  adapter: postgresql
  host: db
  username: inboxed
  password: inboxed
  port: 5432

development:
  <<: *default
  database: inboxed_development

test:
  <<: *default
  database: inboxed_test

production:
  <<: *default
  url: <%= ENV["DATABASE_URL"] %>
```

#### 1.2 API Namespace Structure

Create the controller hierarchy with two auth strategies:

```
app/controllers/
├── application_controller.rb
├── api/
│   └── v1/
│       ├── base_controller.rb      # API key auth
│       └── status_controller.rb    # GET /api/v1/status
└── admin/
    ├── base_controller.rb          # Admin token auth
    └── status_controller.rb        # GET /admin/status
```

**Public API auth** — `Api::V1::BaseController`:
- Reads `Authorization: Bearer <api_key>` header
- For now, returns 401 if header missing, 200 if present (no validation against DB yet)
- Sets `Current.api_key` for downstream controllers

**Admin API auth** — `Admin::BaseController`:
- Reads `Authorization: Bearer <token>` header
- Validates against `ENV["INBOXED_ADMIN_TOKEN"]`
- Returns 401 if invalid

#### 1.3 Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get :status, to: "status#show"
    end
  end

  namespace :admin do
    get :status, to: "status#show"
  end

  get "up", to: "rails/health#show", as: :rails_health_check
end
```

#### 1.4 Status Endpoints

Both status endpoints return:

```json
{
  "service": "inboxed-api",
  "version": "0.0.1",
  "status": "ok",
  "timestamp": "2026-03-14T20:00:00Z"
}
```

The admin endpoint additionally returns:

```json
{
  "service": "inboxed-api",
  "version": "0.0.1",
  "status": "ok",
  "timestamp": "2026-03-14T20:00:00Z",
  "environment": "development",
  "database": "connected",
  "redis": "connected"
}
```

#### 1.5 Production Dockerfile

```dockerfile
# apps/api/Dockerfile
FROM ruby:3.3-slim AS base
WORKDIR /app
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    libpq5 curl && rm -rf /var/lib/apt/lists/*

FROM base AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential libpq-dev && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment true && \
    bundle config set --local without "development test" && \
    bundle install
COPY . .
RUN SECRET_KEY_BASE=placeholder bundle exec rails assets:precompile 2>/dev/null || true

FROM base
COPY --from=build /app /app
COPY --from=build /usr/local/bundle /usr/local/bundle
EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
```

#### 1.6 Core Gems

Add to Gemfile only what's needed now:

```ruby
gem "rack-cors"    # CORS for dashboard SPA
gem "bcrypt"       # Future API key hashing
```

#### 1.7 CORS Configuration

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("DASHBOARD_URL", "http://localhost:5173")
    resource "/api/*", headers: :any, methods: [:get, :post, :put, :patch, :delete, :options]
    resource "/admin/*", headers: :any, methods: [:get, :post, :put, :patch, :delete, :options]
  end
end
```

---

### 2. Svelte Dashboard (`apps/dashboard/`)

#### 2.1 Project Setup

```bash
cd apps/dashboard
npx sv create . --template minimal --types ts
npx svelte-add tailwindcss
npm install
```

SvelteKit with adapter-static for SPA mode.

#### 2.2 SvelteKit Static Adapter

```js
// svelte.config.js
import adapter from '@sveltejs/adapter-static';

export default {
  kit: {
    adapter: adapter({
      fallback: 'index.html'  // SPA fallback
    })
  }
};
```

#### 2.3 Tailwind 4 Theme Tokens

Based on `docs/BRANDING.md` and the design tokens from `docs/screens/`:

```css
/* src/app.css */
@import "tailwindcss";

@theme {
  /* Backgrounds */
  --color-base: #0D0F0E;
  --color-surface: #131614;
  --color-surface-2: #1A1E1B;
  --color-border: #2A302B;

  /* Brand */
  --color-phosphor: #39FF14;
  --color-phosphor-dim: #1A7A08;
  --color-phosphor-glow: rgba(57, 255, 20, 0.12);

  /* Accents */
  --color-amber: #FFB800;
  --color-amber-dim: #7A5800;
  --color-cyan: #00E5FF;
  --color-cyan-dim: #006B78;

  /* Fusion accent (from Stitch screens) */
  --color-primary: #ec5b13;

  /* Text */
  --color-text-primary: #E8F0E9;
  --color-text-secondary: #7A8F7B;
  --color-text-dim: #3D4D3E;

  /* Semantic */
  --color-success: #39FF14;
  --color-warning: #FFB800;
  --color-error: #FF3B30;
  --color-info: #00E5FF;

  /* Typography */
  --font-display: 'Space Grotesk', sans-serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', monospace;
  --font-body: 'Inter', sans-serif;
}
```

#### 2.4 Layout & First Pages

Based on the `docs/screens/` mockups, implement:

**Shell layout** (`src/routes/+layout.svelte`):
- Top header bar: logo `[@] inboxed`, search input, deploy button
- Left sidebar: navigation (Inbox, Sent, Trash), labels, system status
- Main content area
- Reference: `inboxed_2000s_modern_fusion_style_guide/screen.png` and `dashboard_view_fusion/screen.png`

**Pages (static, no API data yet):**
- `/` — Dashboard shell with placeholder inbox list and email preview
- `/login` — Admin token login form (stores token in memory/localStorage, sends as Bearer on API calls)

**Components:**
- `Header.svelte` — top bar with logo, search, actions
- `Sidebar.svelte` — navigation, labels, system status terminal
- `EmailList.svelte` — placeholder email list (hardcoded mock data)
- `EmailPreview.svelte` — placeholder email preview pane

#### 2.5 API Client

```typescript
// src/lib/api.ts
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

export async function apiClient(path: string, options: RequestInit = {}) {
  const token = getAdminToken(); // from store/localStorage
  const res = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
      ...options.headers,
    },
  });
  if (!res.ok) throw new ApiError(res.status, await res.json());
  return res.json();
}
```

#### 2.6 Auth Flow

- `/login` page shows admin token input
- Token stored in memory (Svelte store) and optionally `localStorage`
- All API requests include `Authorization: Bearer <token>`
- If API returns 401, redirect to `/login`
- No user/password — just the `INBOXED_ADMIN_TOKEN`

#### 2.7 Production Dockerfile

```dockerfile
# apps/dashboard/Dockerfile
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM caddy:2-alpine
COPY --from=build /app/build /srv
COPY Caddyfile /etc/caddy/Caddyfile
EXPOSE 80
```

#### 2.8 Caddyfile (dashboard container)

```caddyfile
# apps/dashboard/Caddyfile
:80 {
    root * /srv
    file_server
    try_files {path} /index.html

    handle /api/* {
        reverse_proxy api:3000
    }

    handle /admin/* {
        reverse_proxy api:3000
    }
}
```

### Decision: Caddy as both static server and API proxy

- **Options:** (A) Caddy serves dashboard only, API accessed directly. (B) Caddy serves dashboard and proxies API requests.
- **Chosen:** B — Caddy proxies everything
- **Why:** Single entry point. The dashboard SPA makes fetch calls to `/api/v1/...` on the same origin, avoiding CORS in production. In development, Vite's proxy handles this. Caddy is the production reverse proxy.
- **Trade-offs:** Adds a hop for API requests in production, but Caddy's overhead is negligible. CORS config in Rails is still needed for local dev where the Vite dev server runs on a different port.

---

### 3. MCP Server (`apps/mcp/`)

Minimal initialization only — no tools yet.

```bash
cd apps/mcp
npm init -y
npm install @modelcontextprotocol/sdk typescript @types/node
npx tsc --init
```

#### 3.1 Entry Point

```typescript
// apps/mcp/src/index.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new McpServer({
  name: "inboxed-mcp",
  version: "0.0.1",
});

// Tools will be registered in future specs

const transport = new StdioServerTransport();
await server.connect(transport);
```

#### 3.2 Build Configuration

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "declaration": true
  },
  "include": ["src/**/*"]
}
```

#### 3.3 Production Dockerfile

```dockerfile
# apps/mcp/Dockerfile
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY package*.json ./
EXPOSE 3001
CMD ["node", "dist/index.js"]
```

---

### 4. Docker Compose (Production)

```yaml
# docker-compose.yml
services:
  api:
    build:
      context: apps/api
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgresql://inboxed:inboxed@postgres:5432/inboxed_production
      REDIS_URL: redis://redis:6379/0
      INBOXED_ADMIN_TOKEN: ${INBOXED_ADMIN_TOKEN}
      DASHBOARD_URL: ${DASHBOARD_URL:-http://localhost}
      RAILS_ENV: production
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
    depends_on: [postgres, redis]

  dashboard:
    build:
      context: apps/dashboard
      dockerfile: Dockerfile
    ports:
      - "80:80"
    depends_on: [api]

  mcp:
    build:
      context: apps/mcp
      dockerfile: Dockerfile
    ports:
      - "3001:3001"
    environment:
      INBOXED_API_URL: http://api:3000
      INBOXED_API_KEY: ${INBOXED_MCP_KEY}

  postgres:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: inboxed_production
      POSTGRES_USER: inboxed
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-inboxed}

  redis:
    image: redis:7-alpine
    volumes:
      - redisdata:/data

volumes:
  pgdata:
  redisdata:
```

---

### 5. Devcontainer Updates

Update `.devcontainer/devcontainer.json` to reflect the new structure:

- Add forwarded port for Svelte dev server: `5173`
- Add Svelte VSCode extension: `svelte.svelte-vscode`
- Update port labels: `3200` → "API", add `5173` → "Dashboard Dev"

Update `.devcontainer/post-install.sh` to bootstrap all three apps:

```bash
#!/bin/bash
cd /workspaces/inboxed

# API
cd apps/api && bundle install && cd ../..

# Dashboard
cd apps/dashboard && npm install && cd ../..

# MCP
cd apps/mcp && npm install && cd ../..

echo "✓ All dependencies installed"
```

---

### 6. GitHub Actions CI

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  api:
    name: API (Rails)
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: inboxed
          POSTGRES_PASSWORD: inboxed
          POSTGRES_DB: inboxed_test
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    defaults:
      run:
        working-directory: apps/api
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3"
          bundler-cache: true
          working-directory: apps/api
      - name: Setup DB
        env:
          DATABASE_URL: postgresql://inboxed:inboxed@localhost:5432/inboxed_test
          RAILS_ENV: test
        run: bin/rails db:setup
      - name: Run linter
        run: bundle exec standardrb
      - name: Run tests
        env:
          DATABASE_URL: postgresql://inboxed:inboxed@localhost:5432/inboxed_test
          RAILS_ENV: test
        run: bundle exec rspec

  dashboard:
    name: Dashboard (Svelte)
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/dashboard
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: "npm"
          cache-dependency-path: apps/dashboard/package-lock.json
      - run: npm ci
      - run: npm run lint
      - run: npm run build

  mcp:
    name: MCP Server
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/mcp
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: "npm"
          cache-dependency-path: apps/mcp/package-lock.json
      - run: npm ci
      - run: npm run lint
      - run: npm run build
```

---

### 7. Kamal Deploy Configuration

Update `config/deploy.yml` for the new three-service architecture:

- **api** — primary Rails service, deployed via Kamal
- **dashboard** — Caddy serving Svelte build, deployed as Kamal accessory
- **mcp** — Node MCP server, deployed as Kamal accessory

### Decision: Dashboard and MCP as Kamal accessories

- **Options:** (A) All three as primary Kamal services. (B) API as primary, dashboard + MCP as accessories.
- **Chosen:** B
- **Why:** Kamal's primary service gets zero-downtime deploys and health checks. The API is the critical service. Dashboard and MCP are stateless containers that can be restarted without coordination. Accessories are simpler to configure for this use case.
- **Trade-offs:** Accessories don't get automatic rollback on failure. Acceptable for dashboard (static files) and MCP (stateless).

---

### 8. Branding Implementation

#### 8.1 Design Direction

The `docs/screens/` contain two visual directions:
- **Dark terminal** (`inboxed_style_guide/`): phosphor green, dark backgrounds, monospace-heavy — matches `BRANDING.md`
- **Modern fusion** (`dashboard_view_fusion/`, `landing_page_hero_fusion/`): light theme, orange primary (`#ec5b13`), glossy effects, warmer tone

For the foundation, implement the dark terminal theme as the primary dashboard theme. The fusion orange (`#ec5b13`) is included as `--color-primary` for CTAs and interactive elements — blending both directions.

#### 8.2 Font Loading

Google Fonts loaded in `apps/dashboard/src/app.html`:
- Space Grotesk (display/headings)
- JetBrains Mono (code/addresses/timestamps)
- Inter (body text)

#### 8.3 Static Pages to Implement

Using the mockups as reference, build these as static Svelte components with hardcoded data:

1. **Dashboard shell** — three-column layout (sidebar, inbox list, preview pane)
   - Reference: `dashboard_view_fusion/screen.png` for layout
   - Reference: `inboxed_2000s_modern_fusion_style_guide/screen.png` for dark theme
   - Hardcoded email list with 3-4 mock emails
   - Verification code email in preview pane with `[ copy otp ]` button

2. **Login page** — minimal, centered form
   - Admin token input
   - Inboxed logo and tagline

---

## Technical Decisions Summary

| Decision | Chosen | Why |
|----------|--------|-----|
| Rename `apps/web/` → `apps/api/` | Yes | Reflects API-only architecture |
| Caddy as reverse proxy + static server | Yes | Single entry point, avoids CORS in production |
| Dashboard and MCP as Kamal accessories | Yes | API is the critical service, others are stateless |
| Dark terminal as primary theme | Yes | Matches brand identity, with fusion accents |
| SvelteKit adapter-static (SPA) | Yes | No SSR needed for private dashboard |
| Skip `--skip-action-mailbox` in rails new | Yes | Will add it in the SMTP spec when needed |

---

## Exit Criteria

- [ ] `apps/api/` — Rails API-only app running, `GET /api/v1/status` returns JSON with 200
- [ ] `apps/api/` — `GET /admin/status` returns 401 without token, 200 with valid `INBOXED_ADMIN_TOKEN`
- [ ] `apps/api/` — `GET /api/v1/status` returns 401 without API key header, 200 with any Bearer token
- [ ] `apps/dashboard/` — Svelte SPA builds to static files, loads in browser with Inboxed branding
- [ ] `apps/dashboard/` — Login page accepts admin token, stores it, uses it for API calls
- [ ] `apps/dashboard/` — Dashboard shell renders with sidebar, email list (mock data), preview pane
- [ ] `apps/dashboard/` — Dashboard calls `GET /admin/status` and shows connection status
- [ ] `apps/mcp/` — TypeScript compiles, MCP server starts without errors
- [ ] `docker compose up` — All services start (api + dashboard + mcp + postgres + redis)
- [ ] Dashboard accessible at `http://localhost` via Caddy, API proxied through `/api/*`
- [ ] GitHub Actions CI passes: lint + test + build for all three apps
- [ ] Kamal deploys successfully to VPS
- [ ] After deploy: dashboard loads at `https://inboxed.notdefined.dev` with branding applied

---

## Open Questions

1. **Svelte 5 runes vs legacy mode** — Should we enforce runes (`$state`, `$derived`) from day one? Recommendation: yes, it's the future of Svelte and we have no legacy code.

2. **Admin token rotation** — For foundation, a single `INBOXED_ADMIN_TOKEN` env var is fine. Should we plan for token rotation in the auth middleware now, or defer? Recommendation: defer, it's a post-MVP concern.

3. **Devcontainer `post-install.sh`** — Should it also run `rails db:create db:migrate`? Currently the DB is empty and we have no migrations. Recommendation: yes, add it now so it works when we add migrations in the next spec.
