#!/bin/bash
set -e

VERSION="$1"

if [ -z "$VERSION" ]; then
  echo "❌ Error: You must specify a version number."
  echo "Usage: ./prepare_release.sh <version>"
  exit 1
fi

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
  echo "❌ Error: You have uncommitted changes. Commit or stash them before running this script."
  exit 1
fi

# Update the .toc file
TOC_FILE=$(find . -maxdepth 1 -name "*.toc")
if [ -z "$TOC_FILE" ]; then
  echo "❌ Error: Could not find a .toc file."
  exit 1
fi

echo "📄 Updating version in $TOC_FILE to $VERSION..."
sed -i '' -E "s/## Version:.*/## Version: $VERSION/" "$TOC_FILE"

# Commit the version change
echo "📦 Committing version bump..."
git add "$TOC_FILE"
git commit -m "Set version to $VERSION"

# Tag the version
echo "🏷️ Tagging version $VERSION..."
git tag "$VERSION"

echo "✅ Done. Version set to $VERSION, committed and tagged."