# DNS & Cloudflared Setup

Configure DNS and networking to expose Inboxed to the internet. This covers two traffic paths:

- **HTTP** (API + Dashboard) → via Cloudflare Tunnel (no exposed ports)
- **SMTP** (email reception) → direct to VPS IP (tunnel can't handle raw TCP)

> **Warning:** Incorrect MX records can route real email to your test server. Only configure MX records for domains or subdomains dedicated to testing.

---

## Architecture

```
                    Internet
                       │
        ┌──────────────┼──────────────┐
        │              │              │
   HTTP (443)     SMTP (2525)         │
        │              │              │
   Cloudflare     Direct to VPS      │
   Tunnel              │              │
        │              │              │
        ▼              ▼              │
   ┌─────────────────────────┐        │
   │         VPS             │        │
   │                         │        │
   │  cloudflared ──► :80    │        │
   │    (tunnel)   kamal-proxy       │
   │                  │      │        │
   │              inboxed-web│        │
   │                         │        │
   │  :2525 ──► inboxed-smtp │        │
   │   (direct)              │        │
   └─────────────────────────┘        │
                                      │
```

---

## Step 1: DNS Records in Cloudflare

Go to your domain's DNS settings in the Cloudflare dashboard.

### Required Records

| Type | Name | Value | Proxy | Purpose |
|------|------|-------|-------|---------|
| CNAME | `inboxed` | `<tunnel-id>.cfargotunnel.com` | Proxied (orange) | API via tunnel |
| CNAME | `dashboard.inboxed` | `<tunnel-id>.cfargotunnel.com` | Proxied (orange) | Dashboard via tunnel |
| A | `smtp.inboxed` | `<VPS_IP>` | **DNS only (grey)** | SMTP direct access |
| MX | `inboxed` | `smtp.inboxed.example.com` | — | Routes email to SMTP |
| TXT | `inboxed` | `v=spf1 a:smtp.inboxed.example.com ~all` | — | SPF authorization |

> **Critical:** The SMTP A record must have the orange cloud **OFF** (DNS only / grey). SMTP is raw TCP — Cloudflare's proxy only handles HTTP.

### Example for `notdefined.dev`

| Type | Name | Value | Proxy |
|------|------|-------|-------|
| CNAME | `inboxed` | `abc123.cfargotunnel.com` | Proxied |
| CNAME | `dashboard.inboxed` | `abc123.cfargotunnel.com` | Proxied |
| A | `smtp.inboxed` | `203.0.113.42` | DNS only |
| MX | `inboxed` | `smtp.inboxed.notdefined.dev` | — |
| TXT | `inboxed` | `v=spf1 a:smtp.inboxed.notdefined.dev ~all` | — |

---

## Step 2: Cloudflared Tunnel Configuration

On your VPS, edit the tunnel config:

```bash
# Find your config file
sudo cat /etc/cloudflared/config.yml
# or: ~/.cloudflared/config.yml
```

```yaml
tunnel: <your-tunnel-id>
credentials-file: /path/to/<tunnel-id>.json

ingress:
  # API — kamal-proxy routes to the Rails app
  - hostname: inboxed.example.com
    service: http://localhost:80

  # Dashboard — Caddy serves the SPA
  - hostname: dashboard.inboxed.example.com
    service: http://localhost:8080

  # MCP server (optional — only if you want external access)
  - hostname: mcp.inboxed.example.com
    service: http://localhost:3001

  # Catch-all (required by cloudflared)
  - service: http_status:404
```

Restart cloudflared after editing:

```bash
sudo systemctl restart cloudflared
sudo systemctl status cloudflared
```

### If you don't have a tunnel yet

```bash
# Install cloudflared
curl -fsSL https://pkg.cloudflare.com/cloudflared-stable-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb

# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create inboxed

# Configure (create the config.yml above)
sudo nano /etc/cloudflared/config.yml

# Install as systemd service
sudo cloudflared service install

# Start
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

---

## Step 3: Firewall Rules

```bash
# SSH access
sudo ufw allow 22/tcp

# SMTP — direct access (NOT tunneled)
sudo ufw allow 2525/tcp

# Optional: SMTPS
sudo ufw allow 465/tcp

# HTTP/HTTPS NOT needed — cloudflared handles this via outbound connection
# (the tunnel connects outbound to Cloudflare, no inbound ports needed)

sudo ufw enable
```

---

## Step 4: Verify DNS

Wait a few minutes for DNS propagation, then verify:

```bash
# API — should resolve to Cloudflare IPs (proxied)
dig +short inboxed.example.com
# → 104.21.x.x (Cloudflare)

# SMTP — should resolve to your VPS IP directly
dig +short smtp.inboxed.example.com
# → 203.0.113.42 (your VPS)

# MX — should point to the SMTP hostname
dig +short inboxed.example.com MX
# → 10 smtp.inboxed.example.com

# SPF
dig +short inboxed.example.com TXT
# → "v=spf1 a:smtp.inboxed.example.com ~all"
```

---

## Step 5: Verify Connectivity

### HTTP (via tunnel)

```bash
# API health check
curl https://inboxed.example.com/up
# → {"status":"ok"}

# Dashboard
curl -I https://dashboard.inboxed.example.com
# → HTTP/2 200
```

### SMTP (direct)

```bash
# Test SMTP port
nc -z smtp.inboxed.example.com 2525
# → Connection succeeded

# Send a test email
swaks --to test@inboxed.example.com \
      --from sender@test.local \
      --server smtp.inboxed.example.com:2525 \
      --header "Subject: Hello from Inboxed"
```

---

## App SMTP Configuration

Point your application's SMTP config to the SMTP hostname:

### Rails (Action Mailer)

```ruby
# config/environments/development.rb
config.action_mailer.smtp_settings = {
  address: "smtp.inboxed.example.com",
  port: 2525
}
```

### Node.js (Nodemailer)

```javascript
const transporter = nodemailer.createTransport({
  host: "smtp.inboxed.example.com",
  port: 2525,
  secure: false
});
```

### Django

```python
# settings.py
EMAIL_HOST = "smtp.inboxed.example.com"
EMAIL_PORT = 2525
EMAIL_USE_TLS = False
```

---

## Alternative: No Cloudflared (Direct A Record)

If you don't use cloudflared, expose ports directly:

| Type | Name | Value | Proxy | Purpose |
|------|------|-------|-------|---------|
| A | `inboxed` | `<VPS_IP>` | DNS only | API + Dashboard |
| A | `smtp.inboxed` | `<VPS_IP>` | DNS only | SMTP |
| MX | `inboxed` | `smtp.inboxed.example.com` | — | Email routing |
| TXT | `inboxed` | `v=spf1 a:smtp.inboxed.example.com ~all` | — | SPF |

In this case you'll need:
- `sudo ufw allow 80/tcp` and `sudo ufw allow 443/tcp`
- TLS certificates via Let's Encrypt: `certbot certonly --standalone -d inboxed.example.com`
- Set `ssl: true` in `config/deploy.yml` proxy section

---

## Troubleshooting

### API returns 502 or "tunnel connection failed"

```bash
# Check cloudflared status
sudo systemctl status cloudflared
sudo journalctl -u cloudflared -f

# Check if kamal-proxy is running
docker ps | grep kamal-proxy

# Check internal connectivity
curl http://localhost:80/up
```

### SMTP not reachable

```bash
# Check the SMTP container is running
docker ps | grep smtp

# Check the port is listening
ss -tlnp | grep 2525

# Check firewall
sudo ufw status | grep 2525

# Check from outside
nc -z smtp.inboxed.example.com 2525
```

### MX record not resolving

```bash
# Verify MX
dig +short inboxed.example.com MX

# If empty, the record hasn't propagated yet
# Use dnschecker.org to check global propagation
```

### Emails arrive but can't see them in dashboard

1. Check the API is receiving them: `docker logs inboxed-web | grep "email_received"`
2. Check the dashboard can reach the API: the dashboard makes requests to the API domain
3. Verify `INBOXED_DOMAIN` matches your setup
