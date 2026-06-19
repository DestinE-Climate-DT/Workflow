#!/bin/bash
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
GITHUB_REPO="DestinE-Climate-DT/Workflow"
CI_COMMIT_TAG="${CI_COMMIT_TAG:-}"         # e.g. export CI_COMMIT_TAG=v5.2.3
GH_PAT="${GH_PAT:-}"                       # export GH_PAT=<your token>

# ── Validation ───────────────────────────────────────────────────────────────
if [[ -z "$CI_COMMIT_TAG" ]]; then
  echo "ERROR: CI_COMMIT_TAG is not set. Example: export CI_COMMIT_TAG=v5.2.3"
  exit 1
fi

if [[ -z "$GH_PAT" ]]; then
  echo "ERROR: GH_PAT is not set."
  exit 1
fi

echo "Token length: $(echo -n "$GH_PAT" | wc -c)"
echo "Tag:          $CI_COMMIT_TAG"
echo "Repo:         $GITHUB_REPO"

# ── Git config (skip if already set globally) ────────────────────────────────
git config --global user.email "ci@example.com"
git config --global user.name "GitLab CI"

# ── Mirror logic ─────────────────────────────────────────────────────────────
# Create an orphan branch (no history)
git checkout --orphan mirror-temp

# Stage everything
git add -A
git commit -m "Mirror commit for $CI_COMMIT_TAG"

# Tag the commit
git tag -f "$CI_COMMIT_TAG"

# Add GitHub remote (remove first if it already exists from a previous run)
git remote remove github 2>/dev/null || true
git remote add github "https://x-access-token:${GH_PAT}@github.com/${GITHUB_REPO}.git"

# Push only the tag — no branch history
git push github "refs/tags/$CI_COMMIT_TAG" --force

# Create the GitHub release
GH_TOKEN="$GH_PAT" gh release create "$CI_COMMIT_TAG" \
  --repo "$GITHUB_REPO" \
  --title "Release $CI_COMMIT_TAG" \
  --notes "Release Version $CI_COMMIT_TAG"

echo "Done. Release $CI_COMMIT_TAG published to github.com/$GITHUB_REPO"
