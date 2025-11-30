#!/bin/bash
# Publish script - copies content from Obsidian vault and prepares for GitHub push

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_SOURCE="/home/jabba/Documents/Vishal's Vault/02 Career/portfolio"
CONTENT_DEST="$SCRIPT_DIR/content"

echo "=== Publishing career-portfolio ==="

# Remove symlink if it exists
if [ -L "$CONTENT_DEST" ]; then
    echo "Removing content symlink..."
    rm "$CONTENT_DEST"
fi

# Remove existing content directory if it exists
if [ -d "$CONTENT_DEST" ]; then
    echo "Removing existing content directory..."
    rm -rf "$CONTENT_DEST"
fi

# Copy content from source
echo "Copying content from Obsidian vault..."
cp -r "$CONTENT_SOURCE" "$CONTENT_DEST"

echo "Content copied successfully!"
echo ""
echo "Files copied:"
find "$CONTENT_DEST" -type f -name "*.md" | wc -l
echo "markdown files"

# Stage all changes
echo ""
echo "Staging changes..."
git add -A

echo ""
echo "Ready to commit and push!"
echo "Run: git commit -m 'Update content' && git push"
