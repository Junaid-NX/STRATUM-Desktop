#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 00-bootstrap-repo.sh  —  one-time setup for STRATUM-Desktop
#
# What it does (idempotent where practical):
#   1. git init on the project root (main branch)
#   2. Converts the existing qgroundcontrol/ clone into a pinned submodule
#   3. Stages your STRATUM files, makes the initial commit
#   4. Creates a PRIVATE GitHub repo via gh and pushes
#   5. Tags v0.1.0 as the baseline version
#
# Run from Git Bash (ships with Git for Windows). Run ONCE.
#   cd /c/Users/Anas-NX/OneDrive/NEXAM/10_Systems_Engineering/Systems_Engineering/STRATUM-Desktop
#   bash git/00-bootstrap-repo.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Config — edit if you want a different repo name / owner ──────────────────
REPO_NAME="STRATUM-Desktop"
GH_VISIBILITY="--private"        # change to --public only if you mean it
DEFAULT_BRANCH="main"
BASELINE_TAG="v0.1.0"
# ─────────────────────────────────────────────────────────────────────────────

# Resolve project root = parent of this script's dir, then cd there.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"
echo "==> Project root: $ROOT_DIR"

# ── Pre-flight: required tooling ─────────────────────────────────────────────
command -v git >/dev/null || { echo "ERROR: git not found."; exit 1; }
command -v gh  >/dev/null || { echo "ERROR: GitHub CLI 'gh' not found. Install: https://cli.github.com  then 'gh auth login'."; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERROR: gh not authenticated. Run: gh auth login"; exit 1; }

if [ -d .git ]; then
  echo "ERROR: $ROOT_DIR is already a git repo. This bootstrap is for a fresh repo only."
  exit 1
fi

# ── 1. Init ──────────────────────────────────────────────────────────────────
echo "==> git init ($DEFAULT_BRANCH)"
git init -b "$DEFAULT_BRANCH" >/dev/null
git config core.autocrlf true   # sane CRLF handling on Windows

# ── 2. Convert qgroundcontrol/ to a submodule, pinned to its current commit ──
if [ -d qgroundcontrol/.git ]; then
  QGC_URL="$(git -C qgroundcontrol remote get-url origin)"
  QGC_SHA="$(git -C qgroundcontrol rev-parse HEAD)"
  echo "==> qgroundcontrol -> submodule"
  echo "    url:    $QGC_URL"
  echo "    pinned: $QGC_SHA"

  # Register it as a submodule without re-downloading: write .gitmodules,
  # stage the gitlink, then absorb its .git into the superproject.
  cat > .gitmodules <<EOF
[submodule "qgroundcontrol"]
	path = qgroundcontrol
	url = $QGC_URL
EOF
  git add .gitmodules
  git add qgroundcontrol                       # stages the commit pointer (gitlink)
  git submodule absorbgitdirs qgroundcontrol   # move qgroundcontrol/.git -> .git/modules/...
  git -C qgroundcontrol checkout "$QGC_SHA" 2>/dev/null || true
  echo "    submodule registered."
else
  echo "==> No qgroundcontrol/.git found — skipping submodule step."
fi

# ── 3. Stage everything else + initial commit ────────────────────────────────
echo "==> Staging STRATUM files"
git add -A
git commit -m "chore: initial STRATUM-Desktop baseline

- QGroundControl tracked as submodule (pinned)
- STRATUM docs, flyview-web, build scripts
- repo hygiene: .gitignore, git workflow automation" >/dev/null
echo "    initial commit created."

# ── 4. Create the private GitHub repo + push ─────────────────────────────────
echo "==> Creating PRIVATE GitHub repo: $REPO_NAME"
gh repo create "$REPO_NAME" $GH_VISIBILITY \
  --source=. \
  --remote=origin \
  --description="STRATUM desktop — QGroundControl-based ground station (Qt)" \
  --push
echo "    pushed to origin/$DEFAULT_BRANCH."

# ── 5. Baseline version tag ──────────────────────────────────────────────────
echo "==> Tagging baseline $BASELINE_TAG"
git tag -a "$BASELINE_TAG" -m "$BASELINE_TAG — baseline import"
git push origin "$BASELINE_TAG"

echo ""
echo "✔ Bootstrap complete."
echo "  Repo:     $(gh repo view --json url -q .url 2>/dev/null || echo 'see GitHub')"
echo "  Branch:   $DEFAULT_BRANCH"
echo "  Baseline: $BASELINE_TAG"
echo ""
echo "Next: start a feature ->  bash git/new-feature.sh <feature-name>"
