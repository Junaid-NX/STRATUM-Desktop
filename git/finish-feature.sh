#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# finish-feature.sh [major|minor|patch] ["release note"] [--release]
#
# Ships the CURRENT feature/* branch as a new version:
#   1. Merges feature/* into main with --no-ff (preserves the feature as a unit)
#   2. Bumps semver from the latest vX.Y.Z tag (default: minor)
#   3. Creates an annotated tag carrying the version note (the "comment per version")
#   4. Pushes main + tag
#   5. --release  -> also publishes a GitHub Release with auto-generated notes
#
# Examples:
#   bash git/finish-feature.sh                          # minor bump, auto note
#   bash git/finish-feature.sh minor "Surface map override view"
#   bash git/finish-feature.sh patch "Fix telemetry race" --release
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Parse args ───────────────────────────────────────────────────────────────
BUMP="minor"
NOTE=""
DO_RELEASE="no"
for arg in "$@"; do
  case "$arg" in
    major|minor|patch) BUMP="$arg" ;;
    --release)         DO_RELEASE="yes" ;;
    *)                 NOTE="$arg" ;;
  esac
done

# ── Determine current feature branch ─────────────────────────────────────────
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
case "$BRANCH" in
  feature/*) : ;;
  *) echo "ERROR: Not on a feature/* branch (on '$BRANCH'). Switch to your feature branch first."; exit 1 ;;
esac
FEATURE_SLUG="${BRANCH#feature/}"
[ -z "$NOTE" ] && NOTE="$FEATURE_SLUG"

# ── Guard: clean tree, everything committed ──────────────────────────────────
if ! git diff-index --quiet HEAD --; then
  echo "ERROR: Uncommitted changes on $BRANCH. Commit them before finishing."
  git status --short
  exit 1
fi

# ── Compute next version from latest semver tag ──────────────────────────────
LATEST="$(git tag -l 'v*' --sort=-v:refname | head -n1)"
[ -z "$LATEST" ] && LATEST="v0.0.0"
VER="${LATEST#v}"
MAJOR="${VER%%.*}"; REST="${VER#*.}"; MINOR="${REST%%.*}"; PATCH="${REST#*.}"
case "$BUMP" in
  major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR+1)); PATCH=0 ;;
  patch) PATCH=$((PATCH+1)) ;;
esac
NEW_TAG="v${MAJOR}.${MINOR}.${PATCH}"
echo "==> Version: $LATEST -> $NEW_TAG ($BUMP)"
echo "==> Feature: $BRANCH"
echo "==> Note:    $NOTE"

# ── Merge feature -> main (no-ff keeps the feature visible as one merge) ─────
echo "==> Merging into main"
git checkout main
git pull --ff-only origin main 2>/dev/null || echo "    (offline / no remote update — continuing)"
git merge --no-ff "$BRANCH" -m "merge: $FEATURE_SLUG -> $NEW_TAG

$NOTE"

# ── Annotated version tag (this is the per-version comment) ──────────────────
git tag -a "$NEW_TAG" -m "$NEW_TAG — $NOTE

Feature branch: $BRANCH
Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Push ─────────────────────────────────────────────────────────────────────
echo "==> Pushing main + $NEW_TAG"
git push origin main
git push origin "$NEW_TAG"

# ── Optional GitHub Release ──────────────────────────────────────────────────
if [ "$DO_RELEASE" = "yes" ]; then
  if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    echo "==> Publishing GitHub Release $NEW_TAG"
    gh release create "$NEW_TAG" --title "$NEW_TAG — $NOTE" --generate-notes
  else
    echo "    (gh unavailable/unauthenticated — skipped GitHub Release; tag still pushed)"
  fi
fi

# ── Offer to delete the merged feature branch ────────────────────────────────
echo ""
echo "✔ Shipped $NEW_TAG."
read -r -p "Delete local + remote branch $BRANCH? [y/N] " ans
if [ "${ans:-N}" = "y" ] || [ "${ans:-N}" = "Y" ]; then
  git branch -d "$BRANCH" || git branch -D "$BRANCH"
  git push origin --delete "$BRANCH" 2>/dev/null || true
  echo "  branch removed."
else
  echo "  kept $BRANCH."
fi
