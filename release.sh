#!/bin/bash
set -e

# 1. Get the version from the latest git tag
VERSION=$(git describe --tags --abbrev=0)

# 2. Define folder name
FOLDER="DelveBuddy"
ZIP_NAME="DelveBuddy-v${VERSION}.zip"
RELEASES_DIR="Releases"

mkdir -p "$RELEASES_DIR"

# 3. Clean up any old copies
rm -rf "$RELEASES_DIR/$FOLDER"
rm -f "$RELEASES_DIR/$ZIP_NAME"

RELEASE_FOLDER="$RELEASES_DIR/$FOLDER"

# 4. Create the release folder and copy files, excluding specified items
mkdir "$RELEASE_FOLDER"

rsync -av --exclude="assets-external" \
          --exclude="screenshots" \
          --exclude="deploy.sh" \
          --exclude="release.sh" \
          --exclude="Releases" \
          ./ "$RELEASE_FOLDER" > /dev/null

 # 5. Zip it up
(cd "$RELEASES_DIR" && zip -r "$ZIP_NAME" "$FOLDER") > /dev/null

rm -rf "$RELEASE_FOLDER"

# 6. Done
echo "✅ Created $RELEASES_DIR/$ZIP_NAME"