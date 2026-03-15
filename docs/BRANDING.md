# Inboxed — Branding Guide

> Retro terminal meets modern dev tool. Feels like something you'd find on a BBS in 1994, but runs on your VPS in 2025.

---

## Identity

**Product name:** Inboxed
**Tagline (primary):** *The dev inbox.*
**Tagline (extended):** *Catch emails, webhooks, forms, cron heartbeats — anything your app sends. Inspect everything. Let AI agents access it via MCP.*
**Tagline (alt 1):** *Your emails go nowhere. Your webhooks go nowhere. You see everything.*
**Tagline (alt 2):** *The inbox that catches everything your app sends to the outside world.*
**Tagline (alt 3):** *Catch. Inspect. Assert. Emails, webhooks, and everything in between.*
**Tagline (legacy/email-only):** *Drop test emails into the void. Pull them back with an API.*
**Domain:** inboxed.notdefined.dev  
**SMTP:** mail.notdefined.dev  

---

## Voice & Tone

Inboxed speaks like a senior developer who's been around long enough to find the whole email infrastructure situation mildly absurd — but has built something elegant to deal with it anyway. Dry humor. Precise language. No marketing fluff.

| ✓ Do | ✗ Don't |
|------|---------|
| "Catch. Inspect. Assert." | "Streamline your email workflow" |
| "Your test emails go to `/dev/null`. Readable `/dev/null`." | "Boost team productivity" |
| "No real inboxes were harmed in the making of this test." | "Enterprise-grade email solution" |
| "One API key. Every email. Every webhook. Zero noise." | "Unlock the power of email testing" |
| "Your app talks to the outside world. Now you can listen." | "Centralized communication hub" |
| "Two primitives. Unlimited use cases." | "All-in-one developer platform" |

---

## Color Palette

Retro terminal aesthetic: dark backgrounds, phosphor greens, amber warnings, cool cyan for interactive elements. Tailwind 4 CSS variables.

```css
/* tailwind.config — or CSS vars if using Tailwind v4 @theme */
@theme {
  /* Backgrounds */
  --color-base:        #0D0F0E;   /* near-black, slightly green-tinted */
  --color-surface:     #131614;   /* card/panel background */
  --color-surface-2:   #1A1E1B;   /* elevated surface */
  --color-border:      #2A302B;   /* subtle borders */

  /* Phosphor green — primary brand color */
  --color-phosphor:    #39FF14;   /* electric green, signature color */
  --color-phosphor-dim:#1A7A08;   /* muted green for secondary text */
  --color-phosphor-glow: rgba(57, 255, 20, 0.12); /* for glow effects */

  /* Amber — warnings, highlights, accents */
  --color-amber:       #FFB800;   /* warm amber */
  --color-amber-dim:   #7A5800;   /* muted amber */

  /* Cyan — interactive, links, MCP badge */
  --color-cyan:        #00E5FF;
  --color-cyan-dim:    #006B78;

  /* Text */
  --color-text-primary:   #E8F0E9;   /* almost white, slightly green */
  --color-text-secondary: #7A8F7B;   /* muted green-gray */
  --color-text-dim:       #3D4D3E;   /* very dim, placeholders */

  /* Semantic */
  --color-success:     #39FF14;
  --color-warning:     #FFB800;
  --color-error:       #FF3B30;
  --color-info:        #00E5FF;
}
```

### Color Usage

| Token | Usage |
|-------|-------|
| `phosphor` | Logo, primary CTAs, active states, cursor blink |
| `amber` | Badges, warnings, "new email" indicators, hover accents |
| `cyan` | MCP tag, API endpoints, interactive links |
| `base` | Page background |
| `surface` | Cards, inbox panels, code blocks |
| `text-primary` | Body text, email subjects |
| `text-secondary` | Metadata, timestamps, from addresses |

---

## Typography

Retro terminal feel with modern readability. All available via Google Fonts or Bunny Fonts (privacy-friendly alternative).

```css
@theme {
  /* Display — for headlines, logo wordmark */
  --font-display: 'Space Grotesk', sans-serif;

  /* Mono — for code, email addresses, API keys, terminal output */
  --font-mono: 'JetBrains Mono', 'Fira Code', monospace;

  /* Body — readable, slightly technical feel */
  --font-body: 'Inter', sans-serif;

  /* Retro accent — for taglines, section labels, decorative text */
  --font-retro: 'VT323', monospace;  /* pixel-perfect retro terminal */
}
```

### Type Scale

| Role | Font | Size | Weight | Color |
|------|------|------|--------|-------|
| Logo wordmark | Space Grotesk | 2rem | 700 | phosphor |
| H1 hero | Space Grotesk | 3.5rem | 700 | text-primary |
| H2 section | Space Grotesk | 2rem | 600 | text-primary |
| H3 subsection | Inter | 1.25rem | 600 | text-primary |
| Tagline | VT323 | 1.5rem | 400 | phosphor-dim |
| Body | Inter | 1rem | 400 | text-secondary |
| Code / API | JetBrains Mono | 0.875rem | 400 | cyan |
| Email address | JetBrains Mono | 0.875rem | 400 | text-primary |
| Timestamp | JetBrains Mono | 0.75rem | 400 | text-dim |
| Label / badge | Space Grotesk | 0.75rem | 600 | (varies) |

### VT323 Usage
Use sparingly — only for decorative retro moments:
- Section labels like `[ INBOX ]`, `[ API ]`, `[ MCP ]`
- Terminal-style output in hero section
- Taglines and marketing copy on landing page
- Blinking cursor `▋` animations

---

## Logo

### Concept
A stylized envelope `@` symbol inside a terminal prompt bracket. The `>_` prefix suggests a command being typed; the envelope suggests email. Together they read as "you're in control of your email."

### SVG Logo (Primary — dark background)

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 60" width="200" height="60">
  <defs>
    <filter id="glow">
      <feGaussianBlur stdDeviation="2" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>

  <!-- Terminal prompt bracket -->
  <text x="4" y="44"
    font-family="JetBrains Mono, monospace"
    font-size="40"
    font-weight="700"
    fill="#39FF14"
    filter="url(#glow)"
    opacity="0.7">&#x5B;</text>

  <!-- @ symbol — the core mark -->
  <text x="26" y="46"
    font-family="JetBrains Mono, monospace"
    font-size="36"
    font-weight="700"
    fill="#39FF14"
    filter="url(#glow)">@</text>

  <!-- Closing bracket -->
  <text x="62" y="44"
    font-family="JetBrains Mono, monospace"
    font-size="40"
    font-weight="700"
    fill="#39FF14"
    filter="url(#glow)"
    opacity="0.7">&#x5D;</text>

  <!-- Wordmark -->
  <text x="90" y="42"
    font-family="Space Grotesk, sans-serif"
    font-size="28"
    font-weight="700"
    fill="#E8F0E9"
    letter-spacing="-0.5">inboxed</text>
</svg>
```

### SVG Logo Mark (Icon only — for favicon, GitHub avatar)

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <filter id="glow">
      <feGaussianBlur stdDeviation="1.5" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>

  <!-- Background -->
  <rect width="64" height="64" rx="12" fill="#0D0F0E"/>

  <!-- Brackets -->
  <text x="4" y="48"
    font-family="JetBrains Mono, monospace"
    font-size="44" font-weight="700"
    fill="#39FF14" filter="url(#glow)" opacity="0.6">&#x5B;</text>

  <text x="46" y="48"
    font-family="JetBrains Mono, monospace"
    font-size="44" font-weight="700"
    fill="#39FF14" filter="url(#glow)" opacity="0.6">&#x5D;</text>

  <!-- @ center -->
  <text x="14" y="48"
    font-family="JetBrains Mono, monospace"
    font-size="38" font-weight="700"
    fill="#39FF14" filter="url(#glow)">@</text>
</svg>
```

### Logo Variations

| Variant | Usage |
|---------|-------|
| Full horizontal (SVG above) | Header nav, README banner |
| Icon mark only | Favicon, GitHub avatar, app icon |
| Light version (swap colors) | Light-mode contexts, print |
| Amber variant (swap phosphor → amber) | Warning states, email badges |

---

## UI Patterns

### Terminal Window Component
Wrap code examples and API responses in a fake terminal window:
```
╭─ inboxed ─────────────────────────────╮
│  $ curl inboxed.notdefined.dev/api/v1 │
│  > { "status": "ok", "emails": 3 }   │
╰───────────────────────────────────────╯
```

### Inbox Row
```
▶  user@mail.notdefined.dev          [NEW]
   Welcome to the app · 2s ago
   from: noreply@myproject.test
```

### Blinking Cursor
```css
.cursor::after {
  content: '▋';
  color: var(--color-phosphor);
  animation: blink 1s step-end infinite;
}
@keyframes blink {
  50% { opacity: 0; }
}
```

### Badge Styles
```
[ MCP ]       — cyan background, dark text
[ NEW ]       — amber background, dark text
[ API ]       — phosphor background, dark text
[ 6h TTL ]    — surface-2, dim text
[ MAIL ]      — phosphor background, dark text
[ WEBHOOK ]   — cyan background, dark text
[ FORM ]      — amber background, dark text
[ HEARTBEAT ] — phosphor-dim background, light text
[ HEALTHY ]   — phosphor background, dark text
[ DOWN ]      — error background, light text
```

---

## Landing Page Structure

```
HERO
  [@ inboxed]
  "The dev inbox."
  > Catch emails, webhooks, forms, and cron heartbeats.
  > Inspect everything. Let AI agents access it via MCP.
  [Try Free →]  [Self-Host →]  [GitHub]

SECTION: The problem in one line
  "Your app talks to the outside world.
   You have no idea what it said."

SECTION: Four columns
  [@ Emails]         [~ Webhooks]        [> Forms]           [♥ Heartbeats]
  SMTP catcher       HTTP catcher        Form submissions    Cron monitor
  OTP extraction     Payload inspect     Field parsing       Miss alerts
  MCP + API          MCP + API           MCP + API           MCP + API

SECTION: Terminal demo (animated)
  $ action_mailer → mail.inboxed.dev
  $ curl /api/v1/inboxes/signup@test.local/latest
  > { "subject": "Your OTP is 847291" }
  $ curl -X POST /hook/abc123 -d '{"event":"payment.success"}'
  > { "ok": true }

SECTION: MCP highlight
  "Works with Claude, n8n, and any MCP-compatible agent"
  extract_otp('signup@mail.inboxed.dev')
  wait_for_request('abc123', timeout: 30)

SECTION: Two paths
  [Try Free]                          [Self-Host]
  30-second signup                    docker compose up
  cloud.inboxed.dev                   Unlimited everything
  Perfect for evaluating              MCP, HTML preview, no limits

FOOTER
  [@ inboxed] · notdefined.dev · MIT License
```

---

## Tailwind v4 Setup Notes

With Tailwind v4's CSS-first config, the color tokens map directly:

```css
/* app/assets/stylesheets/application.css */
@import "tailwindcss";

@theme {
  --color-phosphor: #39FF14;
  --color-base: #0D0F0E;
  /* ... rest of tokens above */
}
```

Then in templates:
```html
<span class="text-phosphor font-mono">[@]</span>
<div class="bg-base border border-border rounded-lg p-4">
  <p class="text-text-secondary text-sm font-mono">
    signup+test123@mail.notdefined.dev
  </p>
</div>
```

---

## Inspiration References

- **Vercel** — minimal dark UI, excellent typography hierarchy
- **Linear** — dense information with breathing room, keyboard-first
- **Warp terminal** — retro meets modern, monospace everywhere
- **HTTrack** — old-school terminal aesthetic (what NOT to be, but the vibe)
- **Stripe CLI** — how a dev tool's docs should feel
