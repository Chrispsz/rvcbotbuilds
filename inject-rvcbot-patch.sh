#!/usr/bin/env bash
# ============================================
# RVCBotBuilds - Custom APK Patch Injector
# Injects RVCBotConfig (assets fallback + OTA)
# into the Piko-patched Instagram APK
# ============================================

set -euo pipefail

APK_INPUT="$(readlink -f "${1:?Usage: $0 <input.apk> [output.apk]}")"
APK_OUTPUT="$(readlink -f "${2:-${APK_INPUT%.apk}-rvcbot.apk}" 2>/dev/null || echo "${APK_INPUT%.apk}-rvcbot.apk")"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/patches"
TOOLS_DIR="/tmp/rvcbot-tools"
WORK_DIR="/tmp/rvcbot-patch-work"

echo "============================================"
echo "RVCBotBuilds - APK Patch Injector"
echo "============================================"
echo "Input:  $APK_INPUT"
echo "Output: $APK_OUTPUT"
echo ""

# Check tools
if [ ! -f /tmp/baksmali.jar ]; then
    echo "Downloading baksmali..."
    curl -L -o /tmp/baksmali.jar "https://bitbucket.org/JesusFreke/smali/downloads/baksmali-2.5.2.jar" 2>/dev/null
fi

if [ ! -f /tmp/smali.jar ]; then
    echo "Downloading smali..."
    curl -L -o /tmp/smali.jar "https://bitbucket.org/JesusFreke/smali/downloads/smali-2.5.2.jar" 2>/dev/null
fi

# Verify tools
java -jar /tmp/baksmali.jar --version 2>/dev/null || { echo "ERROR: baksmali not working"; exit 1; }
java -jar /tmp/smali.jar --version 2>/dev/null || { echo "ERROR: smali not working"; exit 1; }

# Clean work directory
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

# Step 1: Extract classes.dex from APK
echo "[1/7] Extracting classes.dex from APK..."
cd "$WORK_DIR"
unzip -o "$APK_INPUT" classes.dex || { echo "ERROR: Could not extract classes.dex from $APK_INPUT"; exit 1; }
ls -la classes.dex

# Step 2: Decompile classes.dex to smali
echo "[2/7] Decompiling classes.dex to smali..."
mkdir -p smali-out
java -jar /tmp/baksmali.jar d classes.dex -o smali-out 2>&1 || { echo "ERROR: baksmali failed"; exit 1; }

# Verify HookFlags.smali exists
HOOK_FLAGS="smali-out/app/morphe/extension/instagram/patches/HookFlags.smali"
if [ ! -f "$HOOK_FLAGS" ]; then
    echo "ERROR: HookFlags.smali not found in DEX. Is this a Piko-patched APK?"
    exit 1
fi
echo "  Found HookFlags.smali ✓"

# Step 3: Add RVCBotConfig smali files
echo "[3/7] Injecting RVCBotConfig patch..."
TARGET_DIR="smali-out/app/morphe/extension/instagram/patches"
cp "$PATCHES_DIR/RVCBotConfig.smali" "$TARGET_DIR/"
cp "$PATCHES_DIR/RVCBotConfig\$1.smali" "$TARGET_DIR/"
echo "  Added RVCBotConfig.smali ✓"
echo "  Added RVCBotConfig\$1.smali ✓"

# Step 4: Modify HookFlags.load() to call RVCBotConfig.init()
echo "[4/7] Modifying HookFlags.load() to call RVCBotConfig.init()..."

# Insert the RVCBotConfig.init() call at the very beginning of load()
# Original load():
#   .method public static load()V
#       .registers 0
#       invoke-static {}, Lapp/morphe/extension/instagram/patches/HookFlags;->profileActionBarFlags()V
#       ...
# Modified:
#   .method public static load()V
#       .registers 1
#       invoke-static {}, Lapp/morphe/extension/instagram/patches/RVCBotConfig;->init()V
#       invoke-static {}, Lapp/morphe/extension/instagram/patches/HookFlags;->profileActionBarFlags()V
#       ...

python3 << 'PYEOF'
import re

hook_flags_path = "smali-out/app/morphe/extension/instagram/patches/HookFlags.smali"

with open(hook_flags_path, 'r') as f:
    content = f.read()

# Find the load() method and modify it
# Change .registers 0 to .registers 1 (we need a register for the init call)
old_load = """.method public static load()V
    .registers 0

    invoke-static {}, Lapp/morphe/extension/instagram/patches/HookFlags;->profileActionBarFlags()V"""

new_load = """.method public static load()V
    .registers 1

    # RVCBotBuilds: Initialize assets fallback + OTA config
    invoke-static {}, Lapp/morphe/extension/instagram/patches/RVCBotConfig;->init()V

    invoke-static {}, Lapp/morphe/extension/instagram/patches/HookFlags;->profileActionBarFlags()V"""

if old_load in content:
    content = content.replace(old_load, new_load)
    with open(hook_flags_path, 'w') as f:
        f.write(content)
    print("  HookFlags.load() modified successfully ✓")
else:
    print("  WARNING: Could not find exact load() pattern, trying flexible match...")
    # Try regex approach
    pattern = r'(\.method public static load\(\)V\s+\.registers )0(\s+)(invoke-static)'
    replacement = r'\g<1>1\2# RVCBotBuilds: Initialize assets fallback + OTA config\n    invoke-static {}, Lapp/morphe/extension/instagram/patches/RVCBotConfig;->init()V\n\n    \3'
    new_content = re.sub(pattern, replacement, content)
    if new_content != content:
        with open(hook_flags_path, 'w') as f:
            f.write(new_content)
        print("  HookFlags.load() modified (regex) ✓")
    else:
        print("  ERROR: Could not modify HookFlags.load()!")
        exit(1)
PYEOF

# Step 5: Reassemble classes.dex
echo "[5/7] Reassembling classes.dex..."
java -jar /tmp/smali.jar a smali-out -o classes-new.dex 2>&1 || { echo "ERROR: smali assembly failed"; exit 1; }
echo "  New classes.dex created ✓"

# Step 6: Update APK (replace classes.dex, add assets)
echo "[6/7] Updating APK..."

# Copy original APK as base
cp "$APK_INPUT" "$APK_OUTPUT"

# Delete old classes.dex from APK
zip -d "$APK_OUTPUT" classes.dex 2>/dev/null || true

# Rename our new dex to classes.dex and add it
cd "$WORK_DIR"
mv -f classes-new.dex classes.dex
zip -0 "$APK_OUTPUT" classes.dex

# Add mc_overrides.json to assets/
MC_OVERRIDES="$SCRIPT_DIR/module/mc_overrides.json"
if [ -f "$MC_OVERRIDES" ]; then
    cd "$WORK_DIR"
    mkdir -p assets
    cp "$MC_OVERRIDES" assets/mc_overrides.json
    zip -0 "$APK_OUTPUT" assets/mc_overrides.json 2>/dev/null
    echo "  Added assets/mc_overrides.json ✓"
else
    echo "  WARNING: mc_overrides.json not found at $MC_OVERRIDES"
fi

# Step 7: Realign and re-sign
echo "[7/7] Realigning and re-signing APK..."

# Zipalign
if command -v zipalign &>/dev/null; then
    zipalign -f 4 "$APK_OUTPUT" "${APK_OUTPUT}.aligned"
    mv "${APK_OUTPUT}.aligned" "$APK_OUTPUT"
    echo "  Aligned ✓"
else
    echo "  WARNING: zipalign not found, skipping alignment"
fi

# Sign with apksigner
APKSIGNER="$SCRIPT_DIR/bin/apksigner.jar"
KEYSTORE="$SCRIPT_DIR/keystore.jks"

# Create keystore if it doesn't exist
if [ ! -f "$KEYSTORE" ]; then
    echo "  Creating debug keystore..."
    keytool -genkey -v -keystore "$KEYSTORE" -alias rvcbot -keyalg RSA -keysize 2048 -validity 10000 -storepass rvcbot123 -keypass rvcbot123 -dname "CN=RVCBot, OU=Builds, O=RVCBotBuilds, L=Remote, ST=Remote, C=BR" 2>/dev/null
fi

if [ -f "$APKSIGNER" ]; then
    java -jar "$APKSIGNER" sign --ks "$KEYSTORE" --ks-key-alias rvcbot --ks-pass pass:rvcbot123 --key-pass pass:rvcbot123 --v2-signing-enabled true --v3-signing-enabled true "$APK_OUTPUT" 2>/dev/null
    echo "  Signed (V2+V3) ✓"
else
    echo "  WARNING: apksigner.jar not found, skipping signing"
    echo "  You'll need to sign manually before installing"
fi

# Final stats
APK_SIZE=$(du -h "$APK_OUTPUT" | cut -f1)
echo ""
echo "============================================"
echo "✅ Build complete!"
echo "Output: $APK_OUTPUT ($APK_SIZE)"
echo ""
echo "Features injected:"
echo "  📦 RVCBotConfig — assets fallback + OTA"
echo "  🔄 First launch: copies mc_overrides.json from APK assets"
echo "  📡 Background: checks GitHub for OTA config updates"
echo "  📂 Import: Piko Settings → Import (no root needed)"
echo "============================================"
