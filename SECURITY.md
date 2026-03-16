# Security Policy

## Scope

Inboxed is a **local/private-network dev tool**, not a production email server. Its threat model is intentionally narrow:

- It runs on your VPS behind your firewall
- It handles test emails, never production user data
- It assumes the operator (you) trusts the network it runs on

That said, vulnerabilities that could allow unauthorized access to captured emails, API key leakage, SMTP open relay behavior, or remote code execution are taken seriously.

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest `main` | ✅ |
| Tagged releases | ✅ Current minor |
| Older releases | ❌ |

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Instead, report them via one of:

- **GitHub Private Vulnerability Reporting** — available in the Security tab of this repo (preferred)
- **Email** — security@notdefined.dev (PGP key available on request)

### What to Include

- Description of the vulnerability and its potential impact
- Steps to reproduce (minimal reproduction preferred)
- Any relevant version info, configuration, or environment details
- Whether you've already developed a fix (not required, but helpful)

### What to Expect

- Acknowledgment within **48 hours**
- Assessment and severity determination within **7 days**
- Fix or mitigation within **30 days** for confirmed vulnerabilities
- Credit in the release notes if you want it

We won't ask you to stay silent indefinitely. If a fix takes longer than 30 days, we'll coordinate a disclosure timeline with you.

## Security Considerations for Self-Hosters

If you're running Inboxed on a public VPS, keep these in mind:

**SMTP Authentication**  
Inboxed requires authentication by default. Never expose port 587/465 without auth enabled. The default config enforces this — don't disable it.

**Not an Open Relay**  
Inboxed only accepts mail addressed to domains explicitly registered in its config. This is enforced at the SMTP level. Do not configure it to accept mail for `*` or all domains.

**API Key Storage**  
API keys are hashed in the database (bcrypt). The plaintext key is only shown once at creation. Treat it like a password.

**Dashboard Auth**
The dashboard uses session-based authentication. On first boot, create an admin account via the setup wizard (`/setup`) using `INBOXED_SETUP_TOKEN`. Consider putting the dashboard behind your VPN or Cloudflare Access if it's publicly reachable.

**Email Content**  
Test emails may contain tokens, OTPs, and magic links. Apply the same access controls you'd apply to a staging secrets store.

**TTL**  
Configure a reasonable TTL for your emails. The default is 7 days. Don't let old test emails accumulate indefinitely.

**Hetzner/VPS Firewall**  
Restrict SMTP ports to known IPs in your cloud firewall if possible. Only your staging servers need to reach port 587.
