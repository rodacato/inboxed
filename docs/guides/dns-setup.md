# DNS Setup

Configure DNS records to receive email on a real domain. This is optional — Inboxed works on localhost without DNS.

> **Warning:** Incorrect MX records can route real email to your test server. Only configure MX records for domains or subdomains dedicated to testing.

## Required Records

| Type | Name | Value | Purpose |
|------|------|-------|---------|
| A | mail.example.com | `<VPS_IP>` | Points to your server |
| MX | example.com | mail.example.com (priority 10) | Routes email to your server |
| TXT | example.com | `v=spf1 a:mail.example.com ~all` | SPF authorization |

Replace `example.com` with your domain and `<VPS_IP>` with your server's public IP.

## Step-by-Step

### Cloudflare

1. Go to DNS settings for your domain
2. Add an **A record**:
   - Name: `mail`
   - IPv4 address: your VPS IP
   - Proxy status: **DNS only** (orange cloud OFF — must be grey)
3. Add an **MX record**:
   - Name: `@` (or your subdomain)
   - Mail server: `mail.example.com`
   - Priority: `10`
4. Add a **TXT record**:
   - Name: `@`
   - Content: `v=spf1 a:mail.example.com ~all`

> **Important:** The A record for the mail server must NOT be proxied through Cloudflare. SMTP traffic cannot pass through the proxy.

### Namecheap

1. Go to Advanced DNS for your domain
2. Add records:
   - A Record: Host `mail`, Value `<VPS_IP>`, TTL Automatic
   - MX Record: Host `@`, Value `mail.example.com`, Priority `10`
   - TXT Record: Host `@`, Value `v=spf1 a:mail.example.com ~all`

### Route 53 (AWS)

```json
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "mail.example.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "<VPS_IP>"}]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "example.com",
        "Type": "MX",
        "TTL": 300,
        "ResourceRecords": [{"Value": "10 mail.example.com"}]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "example.com",
        "Type": "TXT",
        "TTL": 300,
        "ResourceRecords": [{"Value": "\"v=spf1 a:mail.example.com ~all\""}]
      }
    }
  ]
}
```

## Update Inboxed Configuration

After setting up DNS, update your `.env`:

```bash
INBOXED_DOMAIN=mail.example.com
```

Restart services:

```bash
docker compose down && docker compose up -d
```

## Verification

### Check DNS propagation

```bash
# A record
dig +short mail.example.com A

# MX record
dig +short example.com MX

# SPF record
dig +short example.com TXT
```

### Send a test email

```bash
swaks --to test@example.com --server mail.example.com:587
```

### Check from another server

```bash
nslookup -type=MX example.com
```

## TLS Certificates

For STARTTLS support, set TLS certificate paths in your environment:

```bash
SMTP_TLS_CERT=/path/to/fullchain.pem
SMTP_TLS_KEY=/path/to/privkey.pem
```

You can use Let's Encrypt with certbot:

```bash
certbot certonly --standalone -d mail.example.com
```

## Troubleshooting

### Emails not arriving

1. Verify MX record resolves: `dig +short example.com MX`
2. Verify A record resolves: `dig +short mail.example.com A`
3. Check port 587 is open: `nc -z mail.example.com 587`
4. Check firewall rules on your VPS
5. Some providers block port 25 — use 587 instead

### DNS propagation delay

DNS changes can take up to 48 hours to propagate globally. Use [dnschecker.org](https://dnschecker.org) to verify propagation status.
