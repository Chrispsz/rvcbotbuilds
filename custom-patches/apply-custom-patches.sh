#!/usr/bin/env bash
# ============================================
# RVCBotBuilds Custom Smali Patches
# Applied AFTER ReVanced CLI patching
# ============================================
#
# These are patches that don't exist in crimera/piko
# but are available in other mods (InstaEclipse, Instafel).
# We implement them as Smali modifications using apkeditor.
#
# Usage: apply-custom-patches.sh <patched_apk> <pkg_name>
# ============================================

set -euo pipefail

PATCHED_APK="$1"
PKG_NAME="$2"

# Self-contained variables (does NOT depend on utils.sh)
CPT_CWD="$(cd "$(dirname "$0")/.." && pwd)"
CPT_TEMP_DIR="${CPT_CWD}/temp"
CPT_BIN_DIR="${CPT_CWD}/bin"
CPT_APKSIGNER="${CPT_BIN_DIR}/apksigner.jar"
CPT_APKEDITOR="${CPT_TEMP_DIR}/apkeditor.jar"

# Self-contained logging
cpr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }
cepr() { echo >&2 -e "\033[0;31m[-] ${1}\033[0m"; }
cwpr() { echo >&2 -e "\033[0;33m[!] ${1}\033[0m"; }

# Override pr/epr/wpr if not defined (when run from utils.sh context)
if ! declare -f pr >/dev/null 2>&1; then pr() { cpr "$@"; }; fi
if ! declare -f epr >/dev/null 2>&1; then epr() { cepr "$@"; }; fi
if ! declare -f wpr >/dev/null 2>&1; then wpr() { cwpr "$@"; }; fi

# Download apkeditor if not present
ensure_apkeditor() {
        if [ ! -f "$CPT_APKEDITOR" ]; then
                pr "Custom patches: Downloading APKEditor..."
                mkdir -p "$CPT_TEMP_DIR"
                curl -sL "https://github.com/REAndroid/APKEditor/releases/download/V1.4.7/APKEditor-1.4.7.jar" -o "$CPT_APKEDITOR"
        fi
}

# ============================================
# Instagram Custom Patches
# ============================================
apply_instagram_patches() {
        local apk="$1"
        local dir="${apk%.apk}-custom-patch"

        ensure_apkeditor

        pr "Custom patches: Decompiling Instagram for Smali modification..."
        if ! java -jar "$CPT_APKEDITOR" d -i "$apk" -o "$dir" -f 2>&1; then
                epr "Custom patches: Failed to decompile APK"
                rm -rf "$dir" 2>/dev/null || :
                return 1
        fi

        local patched=0

        # ---- Patch 1: Allow Screenshots in DMs ----
        # Removes FLAG_SECURE (0x2000) from Window.setFlags()
        # This allows taking screenshots in DM conversations that normally block them.
        pr "Custom patches: [1/2] Allow Screenshots in DMs (FLAG_SECURE removal)..."
        patched+=$(patch_flag_secure "$dir")

        # ---- Patch 2: MobileConfig Quality Override ----
        # Forces high quality media loading by modifying default config values.
        # This complements "Improve image viewing" (2048px CDN) by also
        # affecting video bitrate and upload quality defaults.
        pr "Custom patches: [2/2] MobileConfig quality defaults..."
        patched+=$(patch_mobileconfig_quality "$dir")

        # ---- Recompile ----
        pr "Custom patches: Recompiling APK..."
        local output="${apk%.apk}-custom.apk"
        if ! java -jar "$CPT_APKEDITOR" b -i "$dir" -o "$output" -f 2>&1; then
                epr "Custom patches: Failed to recompile APK"
                rm -rf "$dir" 2>/dev/null || :
                return 1
        fi

        # ---- Re-sign ----
        pr "Custom patches: Re-signing APK..."
        if ! java -jar "$CPT_APKSIGNER" sign \
                --ks "${CPT_CWD}/ks-p12.keystore" \
                --ks-pass pass:123456789 \
                --key-pass pass:123456789 \
                --ks-key-alias jhc \
                "${output}" 2>&1; then
                epr "Custom patches: Failed to re-sign APK"
                rm -rf "$dir" "$output" 2>/dev/null || :
                return 1
        fi

        # Replace original with custom-patched version
        mv -f "$output" "$apk"
        rm -rf "$dir"
        pr "Custom patches: Applied $patched modifications successfully"
}

# ============================================
# FLAG_SECURE Removal
# ============================================
patch_flag_secure() {
        local dir="$1"
        local count=0

        # Find all smali files that reference Window.setFlags
        while IFS= read -r -d '' smali_file; do
                # Check if this file contains Window.setFlags AND 0x2000
                if grep -q "Landroid/view/Window;->setFlags" "$smali_file" 2>/dev/null && \
                   grep -q "0x2000" "$smali_file" 2>/dev/null; then

                        # Replace ALL const loads of 0x2000 with 0x0
                        # ONLY in files that also reference Window.setFlags
                        # This is safe because FLAG_SECURE is the ONLY common use of 0x2000
                        sed -i 's/\(const\/16\s\+v[0-9]*,\s\+\)0x2000/\10x0/g' "$smali_file" 2>/dev/null || :
                        sed -i 's/\(const\s\+v[0-9]*,\s\+\)0x2000/\10x0/g' "$smali_file" 2>/dev/null || :
                        count=$((count + 1))
                fi
        done < <(find "$dir" -name "*.smali" -print0)

        pr "Custom patches: FLAG_SECURE — patched $count smali files"
        echo "$count"
}

# ============================================
# MobileConfig Quality Override
# ============================================
patch_mobileconfig_quality() {
        local dir="$1"
        local count=0

        # Find strings.xml files and patch quality defaults
        while IFS= read -r -d '' res_file; do
                if grep -q '"medium"' "$res_file" 2>/dev/null; then
                        sed -i 's/"medium"/"high"/g' "$res_file" 2>/dev/null || :
                        count=$((count + 1))
                fi
                if grep -q '"standard"' "$res_file" 2>/dev/null; then
                        sed -i 's/"standard"/"hd"/g' "$res_file" 2>/dev/null || :
                        count=$((count + 1))
                fi
        done < <(find "$dir" -name "strings.xml" -print0)

        # Patch smali quality constants
        while IFS= read -r -d '' smali_file; do
                if grep -q '"medium"' "$smali_file" 2>/dev/null; then
                        sed -i 's/"medium"/"high"/g' "$smali_file" 2>/dev/null || :
                        count=$((count + 1))
                fi
        done < <(find "$dir" -path "*/instagram*" -name "*.smali" -print0 2>/dev/null | head -200)

        pr "Custom patches: MobileConfig quality — patched $count locations"
        echo "$count"
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
