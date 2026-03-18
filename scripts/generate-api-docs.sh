#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPEC_DIR="$REPO_ROOT/docs/api"
OUTPUT="$REPO_ROOT/apps/api/public/docs/index.html"

mkdir -p "$(dirname "$OUTPUT")"

echo "Generating API docs from $SPEC_DIR/openapi.yaml ..."
npx @redocly/cli build-docs "$SPEC_DIR/openapi.yaml" \
  --config "$SPEC_DIR/redocly.yaml" \
  -o "$OUTPUT"

echo "Docs generated at $OUTPUT"
