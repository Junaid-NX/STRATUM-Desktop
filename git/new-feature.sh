#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# new-feature.sh <feature-name>
#
# Starts a feature in its own branch off an up-to-date main.
#   bash git/new-feature.sh override-surface-map
# Creates branch: feature/override-surface-map
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -lt 1 ]; then
  echo "Usage: bash git/new-feature.sh <feature-name>"
  echo "Example: bash git/new-feature.sh telemetry-overlay"
  exit 1
fi

# Normalize: lowercase, spaces->dashes, strip junk.
RAW="$*"
SLUG="$(echo "$RAW" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9._-]//g')"
BRANCH="feature/$SLUG"

# Guard: clean working tree before switching context.
if ! git diff-index --quiet HEAD --; then
  echo "ERROR: You have uncommitted changes. Commit or stash them before starting a new feature."
  git status --short
  exit 1
fi

echo "==> Updating main"
git checkout main
git pull --ff-only origin main || echo "    (no remote update / offline — continuing on local main)"

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "==> Branch $BRANCH exists — switching to it"
  git checkout "$BRANCH"
else
  echo "==> Creating $BRANCH"
  git checkout -b "$BRANCH"
fi

echo ""
echo "✔ On $BRANCH."
echo "  Work, then commit normally:    git add -A && git commit -m \"feat: ...\""
echo "  When done, ship the version:   bash git/finish-feature.sh [major|minor|patch] \"release note\""
