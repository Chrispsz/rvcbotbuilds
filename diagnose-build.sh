#!/usr/bin/env bash
# ============================================
# Build Diagnostics Script
# Run this AFTER a build to analyze what happened.
#
# Usage: ./diagnose-build.sh [build-dir]
#   build-dir: path to build output (default: build/)
#
# This checks:
#   1. Whether patches were actually applied (DEX class check)
#   2. Which piko classes are present in the APK
#   3. Whether the mod menu Activity is registered
#   4. APK size sanity check
#   5. Overlay verification
# ============================================
set -euo pipefail

BUILD_DIR="${1:-build}"
TEMP_DIR="temp"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "============================================"
echo "🔍 RVCBotBuilds — Build Diagnostics"
echo "============================================"
echo ""

ISSUES=0

# 1. Find the built APK
echo "--- APK Check ---"
APK_FILE=$(find "$BUILD_DIR" -name "instagram-morphe-*.apk" -type f 2>/dev/null | head -1)
if [ -z "$APK_FILE" ]; then
    APK_FILE=$(find "$BUILD_DIR" -name "*instagram*.apk" -type f 2>/dev/null | head -1)
fi

if [ -z "$APK_FILE" ]; then
    echo -e "${RED}❌ No Instagram APK found in $BUILD_DIR/${NC}"
    ISSUES=$((ISSUES + 1))
else
    APK_SIZE=$(stat -f%z "$APK_FILE" 2>/dev/null || stat -c%s "$APK_FILE" 2>/dev/null || echo "unknown")
    if [ "$APK_SIZE" != "unknown" ]; then
        APK_SIZE_MB=$((APK_SIZE / 1024 / 1024))
        echo -e "${GREEN}✅ Found APK: $(basename "$APK_FILE") ($APK_SIZE_MB MB)${NC}"
        # Instagram APKs are typically 120-150 MB
        if [ "$APK_SIZE_MB" -lt 100 ]; then
            echo -e "${YELLOW}⚠️  APK is unusually small ($APK_SIZE_MB MB). Patches may not have been applied.${NC}"
            ISSUES=$((ISSUES + 1))
        elif [ "$APK_SIZE_MB" -lt 110 ]; then
            echo -e "${YELLOW}⚠️  APK is small ($APK_SIZE_MB MB). Stock Instagram is usually 120+ MB.${NC}"
        fi
    else
        echo -e "${GREEN}✅ Found APK: $(basename "$APK_FILE")${NC}"
    fi

    # 2. Check for mod classes in the APK
    echo ""
    echo "--- Patch Application Check ---"
    if command -v unzip &>/dev/null; then
        DEX_LIST=$(unzip -l "$APK_FILE" "classes*.dex" 2>/dev/null | grep -o 'classes[0-9]*.dex' | sort -u || true)
        DEX_COUNT=$(echo "$DEX_LIST" | grep -c 'dex' || true)
        echo "  DEX files in APK: $DEX_COUNT"

        # Check for Morphe extension classes
        MORPHE_CLASSES=$(unzip -l "$APK_FILE" 2>/dev/null | grep -c 'app/morphe/extension' || true)
        if [ "$MORPHE_CLASSES" -gt 0 ]; then
            echo -e "  ${GREEN}✅ Morphe extension classes found ($MORPHE_CLASSES)${NC}"
        else
            echo -e "  ${RED}❌ No Morphe extension classes found — patches NOT applied!${NC}"
            ISSUES=$((ISSUES + 1))
        fi

        # Check for HookFlags
        HOOK_FLAGS=$(unzip -l "$APK_FILE" 2>/dev/null | grep -c 'HookFlags' || true)
        if [ "$HOOK_FLAGS" -gt 0 ]; then
            echo -e "  ${GREEN}✅ HookFlags class found${NC}"
        else
            echo -e "  ${RED}❌ HookFlags class NOT found${NC}"
            ISSUES=$((ISSUES + 1))
        fi

        # Check for SettingsActivity
        SETTINGS_ACT=$(unzip -l "$APK_FILE" 2>/dev/null | grep -c 'SettingsActivity' || true)
        if [ "$SETTINGS_ACT" -gt 0 ]; then
            echo -e "  ${GREEN}✅ SettingsActivity class found (mod menu should work)${NC}"
        else
            echo -e "  ${RED}❌ SettingsActivity NOT found (mod menu won't appear)${NC}"
            ISSUES=$((ISSUES + 1))
        fi

        # Check for OtaUpdater
        OTA_UPDATER=$(unzip -l "$APK_FILE" 2>/dev/null | grep -c 'OtaUpdater' || true)
        if [ "$OTA_UPDATER" -gt 0 ]; then
            echo -e "  ${GREEN}✅ OtaUpdater class found${NC}"
        else
            echo -e "  ${YELLOW}⚠️  OtaUpdater NOT found (OTA won't work)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  unzip not available, skipping DEX analysis${NC}"
    fi
fi

# 3. Check build log
echo ""
echo "--- Build Log Analysis ---"
if [ -f "build.md" ]; then
    # Check for Instagram version
    IG_VER=$(grep -i "Instagram-Piko:" build.md 2>/dev/null | head -1 || true)
    if [ -n "$IG_VER" ]; then
        echo "  Version: $IG_VER"
    fi

    # Check for patch failures
    FAIL_COUNT=$(grep -ci "failed\|error\|incompatible" build.md 2>/dev/null || true)
    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠️  $FAIL_COUNT potential error(s) in build log${NC}"
        grep -i "failed\|error\|incompatible" build.md 2>/dev/null | head -5
        ISSUES=$((ISSUES + 1))
    else
        echo -e "  ${GREEN}✅ No obvious errors in build log${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  build.md not found${NC}"
fi

# 4. Check overlay application
echo ""
echo "--- Overlay Verification ---"
OVERLAY_DIR="overlay/piko-patches"
if [ -d "$OVERLAY_DIR" ]; then
    OVERLAY_FILES=$(find "$OVERLAY_DIR" -name "*.java" -o -name "*.kt" | wc -l)
    echo "  Overlay source files: $OVERLAY_FILES"

    # Check HookFlags for fabricated flags
    if [ -f "$OVERLAY_DIR/HookFlags.java" ]; then
        if grep -q 'presetFlags()' "$OVERLAY_DIR/HookFlags.java" 2>/dev/null; then
            echo -e "  ${RED}❌ HookFlags.java still has presetFlags() — fabricated flags!${NC}"
            ISSUES=$((ISSUES + 1))
        else
            echo -e "  ${GREEN}✅ HookFlags.java: no fabricated presetFlags()${NC}"
        fi
    fi
else
    echo -e "  ${YELLOW}⚠️  Overlay directory not found${NC}"
fi

# 5. Check config.toml
echo ""
echo "--- Config Verification ---"
if [ -f "config.toml" ]; then
    # Check for version = "auto"
    IG_VERSION=$(grep '^version = ' config.toml 2>/dev/null | head -1 || true)
    echo "  Instagram version setting: $IG_VERSION"

    # Check for --continue-on-error
    if grep -q '\-\-continue-on-error' config.toml 2>/dev/null; then
        echo -e "  ${YELLOW}⚠️  --continue-on-error is set — patch failures will be hidden${NC}"
        ISSUES=$((ISSUES + 1))
    fi

    # Check for non-existent patches
    if grep -q "'Preset flags'" config.toml 2>/dev/null; then
        echo -e "  ${RED}❌ 'Preset flags' in included-patches — this patch doesn't exist in piko!${NC}"
        ISSUES=$((ISSUES + 1))
    fi

    if grep -q "'Download voice message'" config.toml 2>/dev/null; then
        echo -e "  ${YELLOW}⚠️  'Download voice message' may not exist in piko v3.4.0${NC}"
    fi
fi

# Summary
echo ""
echo "============================================"
if [ "$ISSUES" -gt 0 ]; then
    echo -e "${RED}❌ Found $ISSUES issue(s) that need attention${NC}"
    echo ""
    echo "Common fixes:"
    echo "  1. version = \"auto\" — lets CLI pick the right Instagram version"
    echo "  2. Remove 'Preset flags' from included-patches"
    echo "  3. Remove --continue-on-error from patcher-args"
    echo "  4. Update fork to piko v3.5.0-dev.2+ for Instagram 430 support"
    echo "  5. Ensure overlay is compiled INTO the .mpp, not just applied to source"
else
    echo -e "${GREEN}✅ All checks passed! Build looks healthy.${NC}"
fi
echo "============================================"

# 6. How to get runtime logs
echo ""
echo "--- How to Get Runtime Logs ---"
echo ""
echo "On-device (ADB):"
echo "  adb logcat -s ModDebug PikoUtils | grep -i 'mod\|hook\|ota'"
echo ""
echo "ADB Debug Commands (DebugReceiver):"
echo "  adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command status"
echo "  adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command dump_flags"
echo "  adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command toggle_debug"
echo "  adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command export_log"
echo "  adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command version"
echo ""
echo "In-app (Mod debug):"
echo "  1. Open Instagram → Profile → ⋮ → Mod Settings"
echo "  2. Enable 'Mod debug' at the bottom"
echo "  3. Reproduce the issue"
echo "  4. Check logcat with: adb logcat -s ModDebug"
echo ""
echo "View settings via ADB (no root):"
echo "  adb shell run-as com.instagram.android cat shared_prefs/piko_settings.xml"
echo "  adb shell run-as com.instagram.android cat shared_prefs/piko_ota.xml"
echo ""
echo "Build logs (CI):"
echo "  1. Go to GitHub Actions → select the workflow run"
echo "  2. Look for 'patch_apk' output — it shows which patches were applied"
