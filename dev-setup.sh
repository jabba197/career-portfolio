#!/bin/bash
# Dev setup script - creates symlink to Obsidian vault for local development

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_SOURCE="/home/jabba/Documents/Vishal's Vault/02 Career/portfolio"
CONTENT_DEST="$SCRIPT_DIR/content"

echo "=== Setting up development environment ==="

# Remove existing content (directory or symlink)
if [ -e "$CONTENT_DEST" ] || [ -L "$CONTENT_DEST" ]; then
    echo "Removing existing content..."
    rm -rf "$CONTENT_DEST"
fi

# Create symlink to Obsidian vault
echo "Creating symlink to Obsidian vault..."
ln -s "$CONTENT_SOURCE" "$CONTENT_DEST"

echo "Development setup complete!"
echo "Content symlinked from: $CONTENT_SOURCE"
echo ""
echo "Run './serve.sh' or 'npx quartz build --serve' to start the dev server"
