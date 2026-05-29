#!/usr/bin/env bash
# ============================================
# Immutable Patch Overlay Applier
# Copies our custom files over the piko fork
# after syncing with upstream.
#
# This ensures our modifications are ALWAYS
# present regardless of upstream changes.
# ============================================
set -euo pipefail

OVERLAY_DIR="$(cd "$(dirname "$0")" && pwd)/piko-patches"
PIKO_DIR="${1:?Usage: $0 <piko-repo-dir>}"

# Base paths in piko repo
EXT_BASE="$PIKO_DIR/extensions/instagram/src/main/java/app/morphe/extension/instagram"
PATCHES_DIR="$EXT_BASE/patches"
ENTITY_DIR="$EXT_BASE/entity"
TRANSLATIONS_DIR="$EXT_BASE/constants/translations"
SETTINGS_DIR="$EXT_BASE/settings"
SETTINGS_PREF_DIR="$SETTINGS_DIR/preference"
CONSTANTS_DIR="$EXT_BASE/constants"
PIKO_PATCHES_SRC="$PIKO_DIR/patches/src/main/kotlin/app/crimera/patches/instagram"

echo "============================================"
echo "Immutable Patch Overlay Applier"
echo "============================================"
echo "Overlay:  $OVERLAY_DIR"
echo "Target:   $PIKO_DIR"
echo ""

# Validate target
if [ ! -d "$EXT_BASE" ]; then
    echo "ERROR: Target is not a valid piko repo (missing $EXT_BASE)"
    exit 1
fi

applied=0
failed=0

apply_file() {
    local src="$1"
    local dest="$2"
    local label="${3:-$(basename "$src")}"

    if [ ! -f "$src" ]; then
        echo "  ⚠️  SKIP: $label (source missing)"
        ((failed++)) || true
        return
    fi

    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  ✅ $label"
    ((applied++)) || true
}

echo "--- Core patches ---"
apply_file "$OVERLAY_DIR/Constants.kt"          "$PIKO_PATCHES_SRC/utils/Constants.kt" "Constants (Instagram version compatibility)"
apply_file "$OVERLAY_DIR/HookFlags.java"       "$PATCHES_DIR/HookFlags.java"        "HookFlags (patch flags only, no JSON)"
apply_file "$OVERLAY_DIR/OtaUpdater.java"      "$PATCHES_DIR/OtaUpdater.java"       "OtaUpdater (in-app APK updater)"
apply_file "$OVERLAY_DIR/WelcomeMessage.java"   "$PATCHES_DIR/WelcomeMessage.java"    "WelcomeMessage (debug receiver + OTA)"
apply_file "$OVERLAY_DIR/DebugReceiver.java"   "$PATCHES_DIR/DebugReceiver.java"      "DebugReceiver (ADB debug commands)"

echo ""
echo "--- Entity fixes ---"
apply_file "$OVERLAY_DIR/InstagramButton.java"  "$ENTITY_DIR/InstagramButton.java"    "InstagramButton (setText v430+ fix)"

echo ""
echo "--- Strings & Translations ---"
apply_file "$OVERLAY_DIR/Strings.java"          "$CONSTANTS_DIR/Strings.java"         "Strings (Mod-Instagram folder)"
apply_file "$OVERLAY_DIR/translations/DefaultStrings.java"       "$TRANSLATIONS_DIR/DefaultStrings.java"       "DefaultStrings (Mod rebrand)"
apply_file "$OVERLAY_DIR/translations/StringsPortugueseBR.java"  "$TRANSLATIONS_DIR/StringsPortugueseBR.java"  "StringsPortugueseBR (Mod + OTA)"
apply_file "$OVERLAY_DIR/translations/StringsKorean.java"        "$TRANSLATIONS_DIR/StringsKorean.java"        "StringsKorean (Mod rebrand)"
apply_file "$OVERLAY_DIR/translations/StringsJapanese.java"      "$TRANSLATIONS_DIR/StringsJapanese.java"      "StringsJapanese (Mod rebrand)"
apply_file "$OVERLAY_DIR/translations/StringsHindi.java"         "$TRANSLATIONS_DIR/StringsHindi.java"         "StringsHindi (Mod rebrand)"
apply_file "$OVERLAY_DIR/translations/StringsIndonesian.java"    "$TRANSLATIONS_DIR/StringsIndonesian.java"    "StringsIndonesian (Mod rebrand)"
apply_file "$OVERLAY_DIR/translations/StringsPolish.java"        "$TRANSLATIONS_DIR/StringsPolish.java"        "StringsPolish (Mod rebrand)"
apply_file "$OVERLAY_DIR/translations/StringsRussian.java"       "$TRANSLATIONS_DIR/StringsRussian.java"       "StringsRussian (Mod rebrand)"
apply_file "$OVERLAY_DIR/translations/StringsTurkish.java"       "$TRANSLATIONS_DIR/StringsTurkish.java"       "StringsTurkish (Mod rebrand)"

echo ""
echo "--- Settings UI ---"
apply_file "$OVERLAY_DIR/ScreenBuilder.java"    "$SETTINGS_PREF_DIR/ScreenBuilder.java"    "ScreenBuilder (OTA section)"
apply_file "$OVERLAY_DIR/SettingsActivity.java" "$SETTINGS_DIR/SettingsActivity.java"      "SettingsActivity (OTA section)"

echo ""
echo "============================================"
echo "Overlay applied: $applied files ✅ | $failed skipped ⚠️"
echo "============================================"

# Verify HookFlags was applied correctly
echo ""
echo "--- Verification ---"
if [ -f "$PATCHES_DIR/HookFlags.java" ]; then
    FLAG_COUNT=$(grep -c 'BOOL_FLAGS.put' "$PATCHES_DIR/HookFlags.java" || true)
    echo "  HookFlags boolean flags: $FLAG_COUNT"
    if grep -q 'presetFlags()' "$PATCHES_DIR/HookFlags.java" 2>/dev/null; then
        echo "  ⚠️  WARNING: presetFlags() method still exists (should be removed)"
    else
        echo "  ✅ No fabricated presetFlags() method"
    fi
    if grep -q 'mc_overrides.json' "$PATCHES_DIR/HookFlags.java" 2>/dev/null; then
        echo "  ⚠️  WARNING: mc_overrides.json loading still exists (should be removed)"
    else
        echo "  ✅ No mc_overrides.json loading (patches only)"
    fi
else
    echo "  ⚠️  HookFlags.java not found at target"
fi

# Verify DebugReceiver was applied
if [ -f "$PATCHES_DIR/DebugReceiver.java" ]; then
    echo "  ✅ DebugReceiver.java applied (ADB debug available)"
else
    echo "  ⚠️  DebugReceiver.java not found at target"
fi

# Verify Constants.kt was applied
if [ -f "$PIKO_PATCHES_SRC/utils/Constants.kt" ]; then
    IG_VERSION=$(grep 'version = "' "$PIKO_PATCHES_SRC/utils/Constants.kt" | head -1 | sed 's/.*version = "//;s/".*//')
    echo "  Constants.kt Instagram version: $IG_VERSION"
fi
