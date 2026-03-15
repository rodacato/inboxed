# Deploy with Kamal

Kamal provides zero-downtime deploys and rolling restarts. Use this if you need production-grade deployment for a team.

For most users, [Docker Compose](self-hosting.md) is the recommended approach.

## Prerequisites

- Ruby installed locally (for the Kamal gem)
- SSH access to your VPS
- Container registry credentials (ghcr.io or Docker Hub)

## Setup

Install Kamal:

```bash
gem install kamal
```

Edit `config/deploy.yml` with your server details:

```yaml
service: inboxed

image: ghcr.io/notdefined-dev/inboxed

servers:
  web:
    hosts:
      - your-vps-ip
    labels:
      traefik.http.routers.inboxed.rule: Host(`inboxed.example.com`)

registry:
  server: ghcr.io
  username:
    - KAMAL_REGISTRY_USERNAME
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    RAILS_ENV: production
    INBOXED_DOMAIN: mail.example.com
  secret:
    - SECRET_KEY_BASE
    - INBOXED_ADMIN_TOKEN
    - POSTGRES_PASSWORD
```

Set secrets:

```bash
kamal env push
```

## First Deploy

```bash
kamal setup
```

This will:
1. Install Docker on the remote server (if needed)
2. Set up Traefik as a reverse proxy
3. Push your environment variables
4. Build and deploy the application
5. Run database migrations

## Subsequent Deploys

```bash
kamal deploy
```

## Rollback

```bash
# List recent versions
kamal app versions

# Rollback to previous version
kamal rollback <version>
```

## Logs

```bash
kamal app logs -f
```

## Differences from Docker Compose

| Feature | Docker Compose | Kamal |
|---------|---------------|-------|
| Zero-downtime deploys | No | Yes |
| Built-in reverse proxy | No | Yes (Traefik) |
| Multi-server | No | Yes |
| Rolling restarts | No | Yes |
| Setup complexity | Low | Medium |
| Requires Ruby locally | No | Yes |
