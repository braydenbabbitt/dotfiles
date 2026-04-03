#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_SRC="$SCRIPT_DIR/_plugins"
STOW_PLUGINS="$SCRIPT_DIR/opencode/.config/opencode/plugins"

# Build and copy opencode-meridian
echo "Building opencode-meridian..."
(
	cd "$PLUGINS_SRC/opencode-meridian"
	bun install
	bun run build
)

echo "Copying plugin to stow tree..."
cp "$PLUGINS_SRC/opencode-meridian/dist/index.js" "$STOW_PLUGINS/opencode-meridian.js"

echo "Done! Run 'stow -t ~ opencode' to symlink."
