#!/usr/bin/env bash
# ============================================
# RVCBotBuilds Custom Binary Patches
# Applied AFTER ReVanced CLI patching
# ============================================
#
# These are patches that don't exist in crimera/piko
# but are available in other mods (InstaEclipse, Instafel).
# We implement them as binary DEX modifications — no decompile needed.
#
# Strategy: Binary dex patching is FAST (seconds, not minutes)
# and is used by design — direct DEX byte manipulation requires
# no decompile/recompile step and works reliably on large APKs.
#
# CRITICAL: After modifying DEX bytes, we MUST recalculate the DEX
# header checksums (SHA-1 signature + Adler32 checksum). Without this,
# Android's dex2oat verifier rejects the DEX at install time with
# "App not installed" error.
#
# DEX header layout:
#   Offset  0: magic (8 bytes)
#   Offset  8: checksum (4 bytes, Adler32 of bytes 12..end)
#   Offset 12: signature (20 bytes, SHA-1 of bytes 32..end)
#   Offset 32: file_size (4 bytes)
#
# Usage: apply-custom-patches.sh <patched_apk> <pkg_name>
# ============================================

set -euo pipefail

PATCHED_APK="$1"
PKG_NAME="$2"

# Self-contained variables
CPT_CWD="$(cd "$(dirname "$0")/.." && pwd)"
CPT_TEMP_DIR="${CPT_CWD}/temp"
CPT_BIN_DIR="${CPT_CWD}/bin"
CPT_APKSIGNER="${CPT_BIN_DIR}/apksigner.jar"

# Self-contained logging
cpr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }
cepr() { echo >&2 -e "\033[0;31m[-] ${1}\033[0m"; }
cwpr() { echo >&2 -e "\033[0;33m[!] ${1}\033[0m"; }

if ! declare -f pr >/dev/null 2>&1; then pr() { cpr "$@"; }; fi
if ! declare -f epr >/dev/null 2>&1; then epr() { cepr "$@"; }; fi
if ! declare -f wpr >/dev/null 2>&1; then wpr() { cwpr "$@"; }; fi

# ============================================
# Pre-flight safety checks
# ============================================
if [ ! -f "$PATCHED_APK" ]; then
        epr "Custom patches: APK file not found: $PATCHED_APK"
        exit 1
fi
if [ ! -r "$PATCHED_APK" ]; then
        epr "Custom patches: APK file not readable: $PATCHED_APK"
        exit 1
fi

# ============================================
# Instagram Custom Patches (binary approach)
# ============================================
apply_instagram_patches() {
        local apk="$1"
        # Resolve to absolute path — critical for zip update after cd
        apk="$(cd "$(dirname "$apk")" && pwd)/$(basename "$apk")"
        local tmp_extract="${apk%.apk}-binpatch"
        mkdir -p "$tmp_extract"

        pr "Custom patches: Extracting DEX files from APK..."
        local dex_files
        dex_files=$(unzip -l "$apk" "*.dex" | awk '{print $NF}' | grep -v "^$" | grep "\.dex$")
        local dex_count=$(echo "$dex_files" | wc -l)
        pr "Custom patches: Found $dex_count DEX files"

        local patched=0

        for dex in $dex_files; do
                unzip -o "$apk" "$dex" -d "$tmp_extract" >/dev/null 2>&1 || continue

                # ---- Patch 1: Allow Screenshots in DMs (FLAG_SECURE removal) ----
                # Removes FLAG_SECURE (0x2000) from Window.setFlags() calls
                # In smali bytecode: const/16 vN, 0x2000 → const/16 vN, 0x0000
                # The opcode for const/16 is 0x13, followed by register byte,
                # then 2-byte value in little-endian
                local flag_secure_result
                flag_secure_result=$(patch_flag_secure_binary "$tmp_extract/$dex")
                patched=$((patched + flag_secure_result))

                # ---- Patch 2: MobileConfig Quality Override ----
                # Replace quality strings in DEX string table:
                #   "medium" → "high" (image quality)
                #   "standard" → "hd" (video quality)
                # This works because DEX stores string constants in a string table
                # that can be modified in-place (same length or shorter replacements)
                local quality_result
                quality_result=$(patch_quality_strings "$tmp_extract/$dex")
                patched=$((patched + quality_result))

                # Recalculate DEX checksums if any patches applied
                # This is CRITICAL — without valid checksums, Android rejects the DEX
                if [ "$flag_secure_result" -gt 0 ] || [ "$quality_result" -gt 0 ]; then
                        recalculate_dex_checksums "$tmp_extract/$dex"
                        # Update the dex in the APK
                        # Use absolute paths and cd into extract dir so zip stores
                        # the dex with the correct relative path inside the APK
                        (cd "$tmp_extract" && zip -0 "$apk" "$dex") || {
                                epr "Custom patches: Failed to update $dex in APK"
                        }
                fi
        done

        # Re-sign the APK (binary patches invalidate the signature)
        # Must use --v1-signing-enabled true for APKs targeting older Android
        pr "Custom patches: Re-signing APK..."
        if ! java -jar "$CPT_APKSIGNER" sign \
                --ks "${CPT_CWD}/ks-p12.keystore" \
                --ks-pass pass:123456789 \
                --key-pass pass:123456789 \
                --ks-key-alias jhc \
                --v1-signing-enabled true \
                --v2-signing-enabled true \
                --v3-signing-enabled true \
                "$apk" 2>&1; then
                epr "Custom patches: Failed to re-sign APK"
                rm -rf "$tmp_extract" 2>/dev/null || :
                return 1
        fi

        rm -rf "$tmp_extract"
        pr "Custom patches: Applied $patched binary modifications successfully"
}

# ============================================
# DEX Checksum Recalculation (CRITICAL)
# ============================================
# After modifying DEX bytes, we MUST update:
#   1. SHA-1 signature at offset 12 (over bytes 32..end)
#   2. Adler32 checksum at offset 8 (over bytes 12..end)
# Without this, Android's dex2oat rejects the DEX → "App not installed"
recalculate_dex_checksums() {
        local dex_file="$1"

        python3 -c "
import hashlib, struct, zlib, sys

with open('$dex_file', 'rb') as f:
    data = bytearray(f.read())

# Verify DEX magic
if data[:4] != b'dex\n':
    sys.stderr.write('WARNING: Not a valid DEX file: $dex_file\n')
    sys.exit(0)

# Step 1: Recalculate SHA-1 signature (bytes 32..end → written at offset 12)
sha1 = hashlib.sha1(data[32:]).digest()
data[12:32] = sha1

# Step 2: Recalculate Adler32 checksum (bytes 12..end → written at offset 8)
# DEX uses standard zlib Adler32
checksum = zlib.adler32(bytes(data[12:])) & 0xFFFFFFFF
struct.pack_into('<I', data, 8, checksum)

with open('$dex_file', 'wb') as f:
    f.write(data)
" 2>/dev/null || {
                cwpr "Custom patches: Failed to recalculate DEX checksums for $(basename "$dex_file")"
        }
}

# ============================================
# FLAG_SECURE Removal (binary dex patching)
# ============================================
# Finds const/16 instructions loading 0x2000 (FLAG_SECURE) and zeros them.
# Uses precise pattern matching to avoid false positives:
#   Opcode 0x13 (const/16) + register + 0x00 0x20 (0x2000 LE)
patch_flag_secure_binary() {
        local dex_file="$1"

        # Use python3 for precise binary replacement
        # Only stdout (the count number) is captured by caller
        # Log messages go to stderr to avoid polluting $()
        local result
        result=$(python3 -c "
import struct, sys

with open('$dex_file', 'rb') as f:
    data = bytearray(f.read())

count = 0
i = 0
while i < len(data) - 3:
    # Look for const/16 opcode (0x13) followed by register byte and 0x2000 in LE
    if data[i] == 0x13:  # const/16 opcode
        # Check if the next 2 bytes are 0x00 0x20 (0x2000 in little-endian)
        val = struct.unpack_from('<H', data, i + 2)[0]
        if val == 0x2000:
            # Replace with 0x0000 (no flags)
            struct.pack_into('<H', data, i + 2, 0x0000)
            count += 1
    i += 1

if count > 0:
    with open('$dex_file', 'wb') as f:
        f.write(data)

print(count)
" 2>/dev/null) || result=0

        # Validate result is a number
        if ! [[ "${result:-0}" =~ ^[0-9]+$ ]]; then
                echo "0"
                return
        fi
        if [ "$result" -gt 0 ]; then
                pr "Custom patches: FLAG_SECURE — patched $result occurrences in $(basename "$dex_file")" >&2
        fi
        echo "$result"
}

# ============================================
# MobileConfig Quality Override (binary string replacement)
# ============================================
# Replaces quality string constants in DEX string table:
#   "medium" → "high" (6→4 chars + null padding, safe)
#   "standard" → "hd" (8→2 chars + null padding, safe)
#
# SAFETY: Only operates on DEX files that contain quality-related
# context strings (upload_quality, MobileConfig, image_quality,
# video_quality, quality_tier). Unrelated DEX files are skipped
# to avoid false-positive replacements in strings like "medium_font"
# or "standard_layout" that happen to contain "medium"/"standard".
patch_quality_strings() {
        local dex_file="$1"

        # Only stdout (the count number) is captured by caller
        # Log messages go to stderr to avoid polluting $()
        local result
        result=$(python3 -c "
import struct, sys

with open('$dex_file', 'rb') as f:
    data = bytearray(f.read())

# --- Context gate: only patch DEX files that are quality-related ---
context_strings = [
    b'upload_quality',
    b'MobileConfig',
    b'image_quality',
    b'video_quality',
    b'quality_tier',
]

is_quality_dex = any(ctx in data for ctx in context_strings)
if not is_quality_dex:
    sys.stderr.write('Quality override — skipping $(basename "$dex_file"): no quality context strings found\n')
    print('0', end='')
    sys.exit(0)

count = 0

# Replace 'medium' with 'high\x00\x00' (same length: 6 bytes)
# 'medium' = 6D 65 64 69 75 6D
# 'high\x00\x00' = 68 69 67 68 00 00
needle_medium = b'medium'
replacement_medium = b'high\x00\x00'
idx = 0
while True:
    idx = data.find(needle_medium, idx)
    if idx == -1:
        break
    data[idx:idx+len(needle_medium)] = replacement_medium
    count += 1
    idx += len(needle_medium)

# Replace 'standard' with 'hd\x00\x00\x00\x00\x00\x00' (same length: 8 bytes)
# 'standard' = 73 74 61 6E 64 61 72 64
# 'hd\x00...' = 68 64 00 00 00 00 00 00
needle_standard = b'standard'
replacement_standard = b'hd\x00\x00\x00\x00\x00\x00'
idx = 0
while True:
    idx = data.find(needle_standard, idx)
    if idx == -1:
        break
    data[idx:idx+len(needle_standard)] = replacement_standard
    count += 1
    idx += len(needle_standard)

if count > 0:
    with open('$dex_file', 'wb') as f:
        f.write(data)

print(count)
") || result=0

        # Validate result is a number
        if ! [[ "${result:-0}" =~ ^[0-9]+$ ]]; then
                echo "0"
                return
        fi
        if [ "$result" -gt 0 ]; then
                pr "Custom patches: Quality override — patched $result strings in $(basename "$dex_file")" >&2
        fi
        echo "$result"
}

# ============================================
# Main
# ============================================
case "$PKG_NAME" in
        com.instagram.android)
                apply_instagram_patches "$PATCHED_APK"
                ;;
        *)
                pr "Custom patches: No custom patches for $PKG_NAME"
                ;;
esac
