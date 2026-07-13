#!/usr/bin/env bash
# ============================================
# Auto-update zygisk-detach binaries
# Downloads the latest zygisk-detach release
# from j-hc/zygisk-detach and extracts the
# binaries into module/bin/ and module/zygisk/
#
# Usage: ./scripts/utilities/update-zygisk-detach.sh [module_dir]
# Exits:
#   0 — binaries were updated
#   1 — up-to-date (no binary changes)
#   2 — error (network, extraction, missing files)
#
# Resilience:
#   - Uses gh-api.sh wrapper with retry+backoff for all GitHub API calls
#   - Validates token (warns but continues if anonymous)
#   - Verifies zip extraction integrity
#   - Cleans up temp files on exit
# ============================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=utilities/gh-api.sh
source "$SCRIPT_DIR/gh-api.sh"

REPO="j-hc/zygisk-detach"
MODULE_DIR="${1:-module}"
TRACKING_FILE="build-meta/zygisk-detach-version.txt"

TMP_ZIP="/tmp/zygisk-detach-$$.zip"
TMP_EXTRACT="/tmp/zygisk-detach-extract-$$"
cleanup() { rm -rf "$TMP_ZIP" "$TMP_EXTRACT" 2>/dev/null || true; }
trap cleanup EXIT

# ---- Pre-flight checks -----------------------------------------------------
if [ ! -d "$MODULE_DIR" ]; then
        echo "ERROR: Module dir '$MODULE_DIR' not found" >&2
        exit 2
fi

mkdir -p build-meta

# ---- Token validation (non-fatal — anonymous works but is rate-limited) ----
if [ -n "${GITHUB_TOKEN:-}" ]; then
        if ! gh_api_check_token 2>/dev/null; then
                echo "::warning::GITHUB_TOKEN appears invalid — continuing anonymously (may hit rate limits)" >&2
        fi
fi

# ---- Fetch latest release info (with retry) --------------------------------
echo "→ Fetching latest $REPO release..."
if ! gh_api_get "https://api.github.com/repos/$REPO/releases/latest" - >/dev/null; then
        echo "ERROR: Could not fetch latest release (HTTP $GH_API_LAST_CODE)" >&2
        exit 2
fi

LATEST=$(echo "$GH_API_LAST_BODY" | jq -r '.tag_name // empty')
if [ -z "$LATEST" ]; then
        echo "ERROR: Could not parse tag_name from release response" >&2
        echo "Response body (first 500 chars):" >&2
        echo "$GH_API_LAST_BODY" | head -c 500 >&2
        exit 2
fi

DOWNLOAD_URL=$(echo "$GH_API_LAST_BODY" | jq -r '.assets[0].browser_download_url // empty')
if [ -z "$DOWNLOAD_URL" ]; then
        echo "ERROR: Could not find download URL in release assets" >&2
        exit 2
fi

CURRENT=$(cat "$TRACKING_FILE" 2>/dev/null | tr -d '[:space:]' || echo "")

if [ "$LATEST" = "$CURRENT" ]; then
        echo "✓ zygisk-detach already up-to-date ($LATEST)"
        exit 1
fi

echo "→ Downloading $LATEST ..."
# Asset downloads don't need the API wrapper (different host: objects.githubusercontent.com)
# but we still use curl with retry for resilience
download_ok=0
for attempt in 1 2 3; do
        if curl -sSL --max-time 120 -o "$TMP_ZIP" "$DOWNLOAD_URL"; then
                # Verify it's a valid zip
                if unzip -t "$TMP_ZIP" >/dev/null 2>&1; then
                        download_ok=1
                        break
                fi
        fi
        echo "  download attempt $attempt failed, retrying..." >&2
        sleep $((attempt * 2))
done
if [ "$download_ok" -ne 1 ]; then
        echo "ERROR: Could not download valid zip after 3 attempts" >&2
        exit 2
fi

# ---- Extract ---------------------------------------------------------------
rm -rf "$TMP_EXTRACT"
mkdir -p "$TMP_EXTRACT"
if ! unzip -q "$TMP_ZIP" -d "$TMP_EXTRACT"; then
        echo "ERROR: Failed to extract zip" >&2
        exit 2
fi

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

# ---- Update binaries (idempotent — only writes if different) ---------------
CHANGED=0

copy_if_changed() {
        local src="$1" dst="$2" label="$3"
        if [ -f "$src" ]; then
                mkdir -p "$(dirname "$dst")"
                if ! cmp -s "$src" "$dst" 2>/dev/null; then
                        cp -f "$src" "$dst"
                        chmod 755 "$dst"
                        echo "  ✓ Updated $label"
                        CHANGED=1
                fi
        fi
}

# detach binaries (per arch)
for arch in arm arm64 x86 x64; do
        copy_if_changed \
                "$SRC_DIR/bin/$arch/detach" \
                "$MODULE_DIR/bin/$arch/detach" \
                "bin/$arch/detach"
done

# zygisk .so files
declare -a SO_MAP=(
        "arm64-v8a.so:arm64-v8a.so"
        "armeabi-v7a.so:armeabi-v7a.so"
        "x86.so:x86.so"
        "x86_64.so:x86_64.so"
)
for mapping in "${SO_MAP[@]}"; do
        src_name="${mapping%%:*}"
        dst_name="${mapping##*:}"
        copy_if_changed \
                "$SRC_DIR/zygisk/$src_name" \
                "$MODULE_DIR/zygisk/$dst_name" \
                "zygisk/$dst_name"
done

# ksu_profile binaries (per arch)
for arch in arm arm64 x86 x64; do
        copy_if_changed \
                "$SRC_DIR/bin/$arch/ksu_profile" \
                "$MODULE_DIR/bin/$arch/ksu_profile" \
                "bin/$arch/ksu_profile"
done

# ---- Update tracking + exit ------------------------------------------------
echo "$LATEST" > "$TRACKING_FILE"

if [ "$CHANGED" = "1" ]; then
        echo "✅ zygisk-detach updated to $LATEST"
        exit 0
else
        echo "✓ zygisk-detach $LATEST — no binary changes detected"
        exit 1
fi
