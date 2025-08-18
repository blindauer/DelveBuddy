#!/usr/bin/env bash
# deploy.sh — sync DelveBuddy addon to Live & PTR WoW directories

set -euo pipefail

# Get the directory this script lives in (the project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/"

# Destination folders
LIVE_DEST="/Applications/World of Warcraft/_retail_/Interface/AddOns/DelveBuddy"
PTR_DEST="/Applications/World of Warcraft/_xptr_/Interface/AddOns/DelveBuddy"

echo "Deploying DelveBuddy from:"
echo "  $SOURCE_DIR"
echo
echo " → Live WoW: $LIVE_DEST"
echo " → PTR WoW:  $PTR_DEST"
echo

for DEST in "$LIVE_DEST" "$PTR_DEST"; do
  echo "Syncing to $DEST …"
  mkdir -p "$DEST"
  rsync -av --delete \
    --exclude=".git/" \
    --exclude="*.swp" \
    "$SOURCE_DIR" "$DEST/"
  echo "Done with $DEST."
  echo
done

echo "All done! You can now /reload in both clients."