# Inboxed — Branding & Repo Files Index

> Index of all brand and repository documentation files.

---

## Files in this directory

| File | Purpose |
|------|---------|
| `README.md` | Main repository README — install, usage, API reference |
| `BRANDING.md` | Colors, typography, logo SVG, UI patterns, taglines |
| `CONTRIBUTING.md` | How to contribute — setup, code style, PR process |
| `SECURITY.md` | Vulnerability reporting + self-hosting security notes |
| `LICENSE` | MIT License |
| `CHANGELOG.md` | Version history template |
| `IDENTITY.md` | Profile of the principal developer building this project |
| `EXPERTS.md` | Panel of domain specialists for consultation |
| `ROADMAP.md` | Development phases, tasks, and milestones |
| `AGENTS.md` | Instructions for AI agents working on this project |
| `specs/` | Implementation specs — plans, decisions, and exit criteria per unit of work |

---

## Quick Repo Structure

```
inboxed/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── .env.example
├── docker-compose.yml
├── docker-compose.dev.yml
├── Gemfile
├── package.json
├── app/                    # Rails application
│   ├── mailboxes/          # ActionMailbox receivers
│   ├── models/
│   ├── controllers/api/v1/
│   └── views/              # Hotwire dashboard
├── mcp/                    # Node.js MCP server
│   ├── src/
│   │   ├── index.ts
│   │   └── tools/
│   └── package.json
├── lib/
│   └── inboxed/            # Core SMTP handling
├── spec/                   # RSpec tests
├── docs/                   # Extended documentation
│   ├── specs/              # Implementation specs per unit of work
│   ├── ROADMAP.md
│   ├── IDENTITY.md
│   ├── EXPERTS.md
│   └── BRANDING.md
└── .github/
    ├── workflows/
    │   ├── ci.yml
    │   └── release.yml
    └── ISSUE_TEMPLATE/
        ├── bug_report.md
        └── feature_request.md
```
