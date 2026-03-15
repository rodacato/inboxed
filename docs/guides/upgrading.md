# Upgrading Inboxed

## Standard Upgrade (Docker Compose)

```bash
cd inboxed

# Pull latest code
git pull

# Rebuild and restart services
docker compose up -d --build

# Run database migrations
docker compose exec api rails db:migrate
```

## Using Pre-built Images

If using images from ghcr.io instead of building locally:

```bash
docker compose pull
docker compose up -d
docker compose exec api rails db:migrate
```

## Verify After Upgrade

```bash
bin/check
```

## Rollback

If something goes wrong, revert to the previous version:

```bash
# Check out the previous version
git checkout v1.0.0

# Rebuild and restart
docker compose up -d --build

# Rollback migrations if needed
docker compose exec api rails db:rollback
```

## Breaking Changes

Check [CHANGELOG.md](../../CHANGELOG.md) before upgrading between major versions. Breaking changes will be documented with migration instructions.

## Database Backup Before Upgrade

It's good practice to backup before upgrading:

```bash
docker compose exec db pg_dump -U inboxed inboxed_production > backup-$(date +%Y%m%d).sql
```

To restore if needed:

```bash
cat backup-20260315.sql | docker compose exec -T db psql -U inboxed inboxed_production
```
