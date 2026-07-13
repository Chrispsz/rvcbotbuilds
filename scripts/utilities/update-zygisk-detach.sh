#!/usr/bin/env bash
# ============================================
# Auto-update zygisk-detach binaries
# Downloads the latest zygisk-detach release
# from j-hc/zygisk-detach and extracts the
# binaries into module/bin/ and module/zygisk/
#
# Usage: ./scripts/utilities/update-zygisk-detach.sh
# Exits 0 if updated, 1 if no change, 2 on error
# ============================================
set -euo pipefail

REPO="j-hc/zygisk-detach"
MODULE_DIR="${1:-module}"

if [ ! -d "$MODULE_DIR" ]; then
        echo "ERROR: Module dir '$MODULE_DIR' not found" >&2
        exit 2
fi

# Use GITHUB_TOKEN if available (avoids rate limit)
GH_AUTH=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
        GH_AUTH=(-H "Authorization: token $GITHUB_TOKEN")
fi

echo "→ Fetching latest $REPO release..."
LATEST=$(curl -sL "${GH_AUTH[@]}" "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name // empty')
if [ -z "$LATEST" ]; then
        echo "ERROR: Could not fetch latest release" >&2
        exit 2
fi

TRACKING_FILE="build-meta/zygisk-detach-version.txt"
mkdir -p build-meta
CURRENT=$(cat "$TRACKING_FILE" 2>/dev/null || echo "")

if [ "$LATEST" = "$CURRENT" ]; then
        echo "✓ zygisk-detach already up-to-date ($LATEST)"
        exit 1
fi

DOWNLOAD_URL=$(curl -sL "${GH_AUTH[@]}" "https://api.github.com/repos/$REPO/releases/latest" \
        | jq -r '.assets[0].browser_download_url // empty')
if [ -z "$DOWNLOAD_URL" ]; then
        echo "ERROR: Could not find download URL" >&2
        exit 2
fi

echo "→ Downloading $LATEST ..."
TMP_ZIP="/tmp/zygisk-detach.zip"
TMP_EXTRACT="/tmp/zygisk-detach-extract"
curl -sL "$DOWNLOAD_URL" -o "$TMP_ZIP"
rm -rf "$TMP_EXTRACT"
mkdir -p "$TMP_EXTRACT"
unzip -q "$TMP_ZIP" -d "$TMP_EXTRACT"

# Find the extracted module dir (may be at root or inside a subfolder)
SRC_DIR=""
for candidate in \
        "$TMP_EXTRACT" \
        "$TMP_EXTRACT/zygisk-detach" \
        "$TMP_EXTRACT/module"; do
        if [ -d "$candidate/bin" ] || [ -d "$candidate/zygisk" ]; then
                SRC_DIR="$candidate"
                break
        fi
done

if [ -z "$SRC_DIR" ]; then
        echo "ERROR: Could not find bin/ or zygisk/ in extracted zip" >&2
        echo "Contents:" >&2
        find "$TMP_EXTRACT" -type f >&2
        exit 2
fi

CHANGED=0

# Update detach binaries
for arch in arm arm64 x86 x64; do
        SRC="$SRC_DIR/bin/$arch/detach"
        DST="$MODULE_DIR/bin/$arch/detach"
        if [ -f "$SRC" ]; then
                mkdir -p "$MODULE_DIR/bin/$arch"
                if ! cmp -s "$SRC" "$DST" 2>/dev/null; then
                        cp -f "$SRC" "$DST"
                        chmod 755 "$DST"
                        echo "  ✓ Updated bin/$arch/detach"
                        CHANGED=1
                fi
        fi
done

# Update zygisk .so files
declare -a SO_MAP=(
        "arm64-v8a.so:arm64-v8a.so"
        "armeabi-v7a.so:armeabi-v7a.so"
        "x86.so:x86.so"
        "x86_64.so:x86_64.so"
)
for mapping in "${SO_MAP[@]}"; do
        src_name="${mapping%%:*}"
        dst_name="${mapping##*:}"
        SRC="$SRC_DIR/zygisk/$src_name"
        DST="$MODULE_DIR/zygisk/$dst_name"
        if [ -f "$SRC" ]; then
                mkdir -p "$MODULE_DIR/zygisk"
                if ! cmp -s "$SRC" "$DST" 2>/dev/null; then
                        cp -f "$SRC" "$DST"
                        chmod 755 "$DST"
                        echo "  ✓ Updated zygisk/$dst_name"
                        CHANGED=1
                fi
        fi
done

# Also copy ksu_profile binary if present (used by customize.sh)
for arch in arm arm64 x86 x64; do
        SRC="$SRC_DIR/bin/$arch/ksu_profile"
        DST="$MODULE_DIR/bin/$arch/ksu_profile"
        if [ -f "$SRC" ]; then
                mkdir -p "$MODULE_DIR/bin/$arch"
                if ! cmp -s "$SRC" "$DST" 2>/dev/null; then
                        cp -f "$SRC" "$DST"
                        chmod 755 "$DST"
                        echo "  ✓ Updated bin/$arch/ksu_profile"
                        CHANGED=1
                fi
        fi
done

if [ "$CHANGED" = "1" ]; then
        echo "$LATEST" > "$TRACKING_FILE"
        echo "✅ zygisk-detach updated to $LATEST"
        rm -rf "$TMP_EXTRACT" "$TMP_ZIP"
        exit 0
else
        echo "$LATEST" > "$TRACKING_FILE"
        echo "✓ zygisk-detach $LATEST — no binary changes detected"
        rm -rf "$TMP_EXTRACT" "$TMP_ZIP"
        exit 1
fi
