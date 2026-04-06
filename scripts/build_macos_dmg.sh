#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Build a macOS DMG installer for BIS
# Prerequisites: flutter build macos --release (run this first)
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="BIS"
APP_BUNDLE="$PROJECT_DIR/build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_NAME="BIS-Installer"
DMG_PATH="$PROJECT_DIR/build/${DMG_NAME}.dmg"
STAGING_DIR="$PROJECT_DIR/build/dmg_staging"

# ── Check that the .app exists ──
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found."
    echo "Run 'flutter build macos --release' first."
    exit 1
fi

# ── Clean previous artifacts ──
rm -rf "$STAGING_DIR"
rm -f "$DMG_PATH"

# ── Create staging directory with app + Applications symlink ──
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# ── Create DMG ──
echo "Creating DMG..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# ── Cleanup ──
rm -rf "$STAGING_DIR"

echo ""
echo "✅ DMG created: $DMG_PATH"
echo "   Size: $(du -h "$DMG_PATH" | cut -f1)"
