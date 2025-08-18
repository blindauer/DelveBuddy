#!/usr/bin/env bash
# deploy.sh — sync DelveBuddy addon to Live & PTR WoW directories
# This script now lives in /tools and must resolve the repo root.

set -euo pipefail

# Resolve script directory and repo root (works whether run from any cwd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
SOURCE_DIR="$REPO_ROOT"

# Destination folders
LIVE_DEST="/Applications/World of Warcraft/_retail_/Interface/AddOns/DelveBuddy"
PTR_DEST="/Applications/World of Warcraft/_xptr_/Interface/AddOns/DelveBuddy"

echo "Deploying DelveBuddy from:"
echo "  SOURCE_DIR=$SOURCE_DIR"
echo "  SCRIPT_DIR=$SCRIPT_DIR"
echo "  REPO_ROOT=$REPO_ROOT"
echo
echo " → Live WoW: $LIVE_DEST"
echo " → PTR WoW:  $PTR_DEST"
echo

for DEST in "$LIVE_DEST" "$PTR_DEST"; do
  echo "Syncing to $DEST …"
  mkdir -p "$DEST"
  rsync -av --delete --delete-excluded \
    --exclude=".git/" \
    --exclude=".gitignore" \
    --exclude=".DS_Store" \
    --exclude=".vscode/" \
    --exclude="tools/" \
    --exclude="*.swp" \
    "$SOURCE_DIR/" "$DEST/"
  echo "Done with $DEST."
  echo
done

echo "All done! You can now /reload in the clients."