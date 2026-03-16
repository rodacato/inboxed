# Self-Hosting Guide

Complete walkthrough from a blank VPS to a running Inboxed instance.

## Prerequisites

- VPS with 1GB RAM, 10GB disk (any Linux distro)
- Docker and Docker Compose v2 installed
- A domain name (optional — localhost works for testing)

## Step 1: Clone and Setup

```bash
git clone https://github.com/rodacato/inboxed
cd inboxed
bin/setup
```

The setup script will:
- Check that Docker and Docker Compose are installed
- Ask for your domain, dashboard port, and SMTP port
- Generate cryptographic secrets automatically
- Write a `.env` file with `chmod 600`

## Step 2: Start Services

```bash
docker compose up -d
```

This starts five services:
- **API** (Rails) on port 3000
- **Dashboard** on port 80 (configurable)
- **MCP server** on port 3001
- **PostgreSQL** on port 5432
- **Redis** on port 6379

## Step 3: Verify Installation

```bash
bin/check
```

Expected output:
```
[@] Inboxed Health Check
  ✓ API          (http://localhost:3000/up)
  ✓ Dashboard    (http://localhost:80)
  ✓ Database     (PostgreSQL)
  ✓ Redis
  ✓ SMTP         (port 587)

  5 passed, 0 failed
```

## Step 4: Send Your First Test Email

```bash
swaks --to test@localhost --server localhost:587
```

Open http://localhost in your browser — the email should appear in the dashboard.

## Step 5: Configure Your App's SMTP

Point your application's SMTP configuration at Inboxed:

### Rails

```ruby
# config/environments/test.rb
config.action_mailer.smtp_settings = {
  address: "localhost",
  port: 587
}
```

### Node.js (Nodemailer)

```javascript
const transporter = nodemailer.createTransport({
  host: "localhost",
  port: 587,
  secure: false,
});
```

### Django

```python
# settings.py
EMAIL_HOST = "localhost"
EMAIL_PORT = 587
```

## Step 6: DNS Setup (Optional)

If you want to receive email on a real domain, see the [DNS setup guide](dns-setup.md).

## Firewall Rules

If running on a VPS, open only the ports you need:

```bash
# Dashboard
ufw allow 80/tcp

# SMTP (only if receiving external email)
ufw allow 587/tcp

# API (only if accessed externally)
ufw allow 3000/tcp
```

Keep PostgreSQL (5432) and Redis (6379) closed to the internet.

## Monitoring & Logs

View logs for all services:

```bash
docker compose logs -f
```

View logs for a specific service:

```bash
docker compose logs -f api
docker compose logs -f dashboard
```

Rails API logs are structured JSON in production:

```json
{"method":"GET","path":"/api/v1/inboxes","status":200,"duration":12.34,"request_id":"abc-123","ip":"10.0.0.1"}
```

SMTP server logs:

```json
{"service":"smtp","event":"email_received","from":"app@example.com","to":"test@mail.inboxed.dev","size_bytes":4521,"duration_ms":45}
```

## Backup & Restore

### Backup

```bash
docker compose exec db pg_dump -U inboxed inboxed_production > backup.sql
```

### Restore

```bash
cat backup.sql | docker compose exec -T db psql -U inboxed inboxed_production
```

## Troubleshooting

### Services won't start

```bash
docker compose ps
docker compose logs --tail=20
```

### Port already in use

Edit `.env` to change the conflicting port, then restart:

```bash
docker compose down && docker compose up -d
```

### Database connection refused

Ensure the `db` service is healthy:

```bash
docker compose exec db pg_isready -U inboxed
```

### Emails not arriving

1. Check SMTP port is reachable: `nc -z localhost 587`
2. Check API logs: `docker compose logs api --tail=50`
3. Verify your app's SMTP config points to the correct host and port
