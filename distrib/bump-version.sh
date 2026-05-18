#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SHARD="shard.yml"

# --- helpers ---
semver_parse() {
  local v="$1"
  v="${v#v}"
  IFS='.' read -r major minor patch <<< "$v"
  major="${major:-0}"; minor="${minor:-0}"; patch="${patch:-0}"
  echo "$major $minor $patch"
}

semver_format() {
  echo "$1.$2.$3"
}

bump_minor() {
  read -r mjr mnr ptch <<< "$(semver_parse "$1")"
  semver_format "$mjr" "$((mnr + 1))" 0
}

bump_patch() {
  read -r mjr mnr ptch <<< "$(semver_parse "$1")"
  semver_format "$mjr" "$mnr" "$((ptch + 1))"
}

# --- determine current version ---
CUR_VER="$(awk '/^version:/ {print $2; exit}' "$SHARD")"
echo "Current version: $CUR_VER"

# --- find latest tag ---
LAST_TAG="$(git tag --sort=-version:refname | head -1 || true)"
if [[ -z "$LAST_TAG" ]]; then
  echo "No tags found — using full log since beginning"
  LOG_RANGE="HEAD"
else
  echo "Last tag: $LAST_TAG"
  LOG_RANGE="${LAST_TAG}..HEAD"
fi

# --- analyse commits ---
COMMITS="$(git log "$LOG_RANGE" --oneline 2>/dev/null || true)"
if [[ -z "$COMMITS" ]]; then
  echo "No new commits since last tag. Nothing to bump."
  exit 0
fi

echo ""
echo "Commits since last tag:"
echo "$COMMITS"
echo ""

BUMP="patch"
while IFS= read -r line; do
  # strip hash prefix like "abc123 "
  msg="${line#* }"
  case "$msg" in
    *'!'*)    BUMP="major" ;;   # breaking: any commit with !
    feat!*|fix!*) BUMP="major" ;;
    feat*)    BUMP="minor" ;;
  esac
done <<< "$COMMITS"

# --- compute new version ---
case "$BUMP" in
  major)
    read -r mjr _ _ <<< "$(semver_parse "$CUR_VER")"
    NEW_VER="$(semver_format "$((mjr + 1))" 0 0)"
    echo "Bump: major ($NEW_VER)"
    ;;
  minor)
    NEW_VER="$(bump_minor "$CUR_VER")"
    echo "Bump: minor ($NEW_VER)"
    ;;
  patch)
    NEW_VER="$(bump_patch "$CUR_VER")"
    echo "Bump: patch ($NEW_VER)"
    ;;
esac

# --- update shard.yml ---
sed -i "s/^version: ${CUR_VER}/version: ${NEW_VER}/" "$SHARD"
echo ""
echo "Updated $SHARD: $CUR_VER → $NEW_VER"
echo ""
echo "Create tag and commit?"
echo "  git commit -m 'release: v$NEW_VER' && git tag -a v$NEW_VER -m 'v$NEW_VER'"
