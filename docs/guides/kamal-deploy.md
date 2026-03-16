# Deploy with Kamal + GitHub Actions

Zero-downtime deploys via Kamal, automated through GitHub Actions. Merge to `production`, everything else is automatic.

For simpler setups, see [Docker Compose self-hosting](self-hosting.md).

---

## Architecture

```
Push/merge to production
    ↓
CI (tests + lint)
    ↓
Docker Build & Push (3 images → ghcr.io)
    ↓
Deploy workflow (kamal deploy → VPS)
    ↓
Production ✓
```

**Images built:**

| Image | Source | Purpose |
|-------|--------|---------|
| `ghcr.io/your-org/inboxed-api` | `apps/api/Dockerfile` | Rails API + SMTP server |
| `ghcr.io/your-org/inboxed-dashboard` | `apps/dashboard/Dockerfile` | Svelte SPA (Caddy) |
| `ghcr.io/your-org/inboxed-mcp` | `apps/mcp/Dockerfile` | MCP server (Node.js) |

**Kamal manages on the VPS:**

| Container | Role |
|-----------|------|
| `inboxed-web` | Rails API (Puma + Solid Queue) |
| `inboxed-smtp` | SMTP reception server |
| `inboxed-dashboard` | Dashboard static files |
| `inboxed-mcp` | MCP server |
| `inboxed-db` | PostgreSQL 16 |
| `inboxed-redis` | Redis 7 |
| `kamal-proxy` | Reverse proxy (port 80) |

---

## Prerequisites

- VPS with SSH access (1 GB RAM minimum, Ubuntu 22.04+ recommended)
- Docker installed on the VPS (`curl -fsSL https://get.docker.com | sh`)
- GitHub repository with Actions enabled
- Cloudflared tunnel configured on VPS (handles TLS)
- Ruby 3.3+ locally (only needed for `kamal setup` — not for CI deploys)

---

## Step 1: Generate Secrets

Run these locally and save the output — you'll need them for GitHub Secrets:

```bash
# Rails secret
openssl rand -hex 64

# Setup token (one-time, for creating admin account)
openssl rand -hex 32

# PostgreSQL password
openssl rand -hex 32

# MCP server key
openssl rand -hex 32
```

---

## Step 2: Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions** in your GitHub repo.

### Required Secrets

| Secret | Value | How to generate |
|--------|-------|-----------------|
| `HOST_IP` | Your server's public IP | `curl ifconfig.me` on your VPS |
| `SSH_PRIVATE_KEY` | Full content of your SSH private key | `cat ~/.ssh/id_rsa` (the key must be in `~/.ssh/authorized_keys` on VPS) |
| `KAMAL_REGISTRY_PASSWORD` | GitHub Personal Access Token | GitHub → Settings → Developer Settings → PAT (classic) with `write:packages` scope |
| `SECRET_KEY_BASE` | 128-char hex string | `openssl rand -hex 64` |
| `INBOXED_SETUP_TOKEN` | 64-char hex string | `openssl rand -hex 32` |
| `POSTGRES_PASSWORD` | 64-char hex string | `openssl rand -hex 32` |
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://inboxed:<POSTGRES_PASSWORD>@localhost:5432/inboxed_production` |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379/0` |
| `INBOXED_MCP_KEY` | 64-char hex string | `openssl rand -hex 32` |
| `OUTBOUND_SMTP_HOST` | SMTP relay for system emails | `smtp.resend.com` (optional) |
| `OUTBOUND_FROM_EMAIL` | From address for system emails | `noreply@yourdomain.com` (optional) |
| `GITHUB_CLIENT_ID` | GitHub OAuth client ID | *(optional, enables GitHub login)* |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth client secret | *(optional)* |

### Required Variables (not secrets)

Go to **Settings → Secrets and variables → Actions → Variables tab**.

| Variable | Value | Example |
|----------|-------|---------|
| `INBOXED_DOMAIN` | Your domain for the API | `inboxed.example.com` |
| `REGISTRATION_MODE` | Registration policy | `closed` (default), `open`, or `invite_only` |
| `TRIAL_DURATION_DAYS` | Trial days for new orgs | `7` (default, only applies when `open`) |
| `EMAIL_TTL_HOURS` | Email retention hours | `168` (default, 7 days) |

> **Important:** `DATABASE_URL` must use the same password as `POSTGRES_PASSWORD`.

---

## Step 3: Cloudflared Tunnel

Your VPS already has cloudflared. Make sure the tunnel routes traffic to the right ports:

```yaml
# ~/.cloudflared/config.yml (on VPS)
tunnel: <your-tunnel-id>
credentials-file: /root/.cloudflared/<tunnel-id>.json

ingress:
  # API — kamal-proxy listens on port 80
  - hostname: inboxed.example.com
    service: http://localhost:80

  # Dashboard (optional subdomain)
  - hostname: dashboard.inboxed.example.com
    service: http://localhost:8080

  # MCP server (optional, for external access)
  - hostname: mcp.inboxed.example.com
    service: http://localhost:3001

  # Catch-all
  - service: http_status:404
```

After editing, restart cloudflared:

```bash
sudo systemctl restart cloudflared
```

> **Note:** SMTP (port 2525) is NOT tunneled through Cloudflare — it's exposed directly. Ensure your firewall allows inbound TCP on port 2525.

---

## Step 4: First Deploy (kamal setup)

The first deploy must be run manually because it installs Docker, kamal-proxy, and boots the accessories (database, redis).

```bash
# On your local machine
gem install kamal

# Export all secrets as environment variables
export HOST_IP=<your-vps-ip>
export KAMAL_REGISTRY_PASSWORD=<your-github-pat>
export SECRET_KEY_BASE=<generated>
export INBOXED_SETUP_TOKEN=<generated>
export POSTGRES_PASSWORD=<generated>
export DATABASE_URL=postgresql://inboxed:<POSTGRES_PASSWORD>@localhost:5432/inboxed_production
export REDIS_URL=redis://localhost:6379/0
export INBOXED_MCP_KEY=<generated>

# Run setup (installs everything, first deploy)
kamal setup
```

This will:
1. Install Docker on the VPS (if needed)
2. Start kamal-proxy (reverse proxy on port 80)
3. Boot accessories: PostgreSQL, Redis, Dashboard, MCP
4. Build and push the API image
5. Deploy the web and SMTP containers
6. Run database migrations

### Verify

```bash
# Health check
curl https://inboxed.example.com/up

# Send a test email
swaks --to test@inboxed.example.com \
      --from sender@example.com \
      --server <HOST_IP>:2525 \
      --header "Subject: Hello from Inboxed"

# Check logs
kamal app logs -f
```

---

## Step 5: Automatic Deploys (CI/CD)

After the first setup, every push to `production` triggers:

1. **CI** (`.github/workflows/ci.yml`) — runs tests and lint
2. **Docker Build** (`.github/workflows/docker.yml`) — builds multi-arch images, pushes to ghcr.io
3. **Deploy** (`.github/workflows/deploy.yml`) — runs `kamal deploy` on success

No manual steps needed. Just push code.

---

## Common Operations

### View logs

```bash
kamal app logs -f              # API logs
kamal app logs -f -r smtp      # SMTP server logs
kamal accessory logs dashboard  # Dashboard logs
```

### Rails console

```bash
kamal app exec -i 'bin/rails console'
```

### Database operations

```bash
# Run migrations manually
kamal app exec 'bin/rails db:migrate'

# Database backup
kamal accessory exec db 'pg_dump -U inboxed inboxed_production' > backup.sql
```

### Rollback

```bash
kamal app versions          # List deployed versions
kamal rollback <version>    # Rollback to a specific version
```

### Reboot accessories

```bash
kamal accessory reboot db
kamal accessory reboot redis
kamal accessory reboot dashboard
```

### Update accessories (new images)

```bash
kamal accessory boot dashboard  # Pull latest and restart
```

---

## Firewall Rules

```bash
# Required
sudo ufw allow 22/tcp       # SSH
sudo ufw allow 2525/tcp     # SMTP (direct, not tunneled)

# NOT needed if using cloudflared (tunnel handles 80/443)
# sudo ufw allow 80/tcp
# sudo ufw allow 443/tcp

# Optional — only if exposing SMTPS
sudo ufw allow 465/tcp

sudo ufw enable
```

---

## Troubleshooting

### Deploy fails with "permission denied"

Your SSH key doesn't have access. Ensure `SSH_PRIVATE_KEY` corresponds to a public key in `~/.ssh/authorized_keys` on the VPS.

### Images not found

Check that the Docker Build workflow ran successfully. Images must be at:
- `ghcr.io/your-org/inboxed-api:latest`
- `ghcr.io/your-org/inboxed-dashboard:latest`
- `ghcr.io/your-org/inboxed-mcp:latest`

### Database connection refused

The PostgreSQL accessory might not be ready. Check:

```bash
kamal accessory details db
kamal accessory logs db
```

### Cloudflared not routing

```bash
# On VPS — check tunnel status
sudo systemctl status cloudflared
cloudflared tunnel info

# Test internal connectivity
curl http://localhost:80/up
```

### SMTP not reachable

SMTP runs on port 2525 by default (not 25, to avoid root requirements). Make sure:
- Firewall allows TCP 2525
- Your email client/app points to `<HOST_IP>:2525`

---

## Differences from Docker Compose

| Feature | Docker Compose | Kamal + CI/CD |
|---------|---------------|---------------|
| Zero-downtime deploys | No | Yes |
| Automatic on push | No | Yes |
| Rolling restarts | No | Yes |
| Multi-arch images | Manual | Automatic (amd64 + arm64) |
| Setup complexity | Low | Medium (one-time) |
| Rollback | Manual | `kamal rollback` |
| Requires Ruby locally | No | Only for first setup |
