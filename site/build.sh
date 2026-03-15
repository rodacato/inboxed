#!/usr/bin/env bash
set -euo pipefail

# Build Tailwind CSS using standalone CLI
# Download: https://github.com/tailwindlabs/tailwindcss/releases

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if command -v npx &>/dev/null; then
  npx @tailwindcss/cli -i styles/main.css -o styles/output.css --minify
elif command -v tailwindcss &>/dev/null; then
  tailwindcss -i styles/main.css -o styles/output.css --minify
else
  echo "Error: tailwindcss CLI not found."
  echo "Install: npm install -g @tailwindcss/cli"
  echo "Or download standalone: https://github.com/tailwindlabs/tailwindcss/releases"
  exit 1
fi

echo "✓ CSS built: styles/output.css"
