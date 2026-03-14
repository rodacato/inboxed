#!/usr/bin/env bash
set -euo pipefail

echo "==> [inboxed] Post-install starting..."

# ── Rails app setup ──────────────────────────────────────────
if [ -f apps/web/Gemfile ]; then
  echo "==> Installing Ruby dependencies..."
  cd apps/web
  bundle install
  echo "==> Setting up database..."
  bin/rails db:prepare || true
  cd /workspaces/inboxed
fi

# ── MCP server setup ─────────────────────────────────────────
if [ -f apps/mcp/package.json ]; then
  echo "==> Installing MCP dependencies..."
  cd apps/mcp
  npm install
  cd /workspaces/inboxed
fi

# ── Kamal ─────────────────────────────────────────────────────
if command -v gem &>/dev/null; then
  echo "==> Installing Kamal..."
  gem install kamal --no-document || true
fi

# ── Shell niceties ────────────────────────────────────────────
echo "==> Configuring shell..."
cat >> ~/.bashrc << 'ALIASES'

# Inboxed shortcuts
alias be="bundle exec"
alias rs="cd /workspaces/inboxed/apps/web && bin/rails server -b 0.0.0.0 -p 3000"
alias rc="cd /workspaces/inboxed/apps/web && bin/rails console"
alias mcp="cd /workspaces/inboxed/apps/mcp && npm run dev"
ALIASES

echo "==> [inboxed] Post-install complete!"
