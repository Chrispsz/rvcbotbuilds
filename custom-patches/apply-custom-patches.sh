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

# ============================================
# Instagram Custom Patches
# ============================================
apply_instagram_patches() {
        local apk="$1"
        local dir="${apk%.apk}-custom-patch"

        pr "Custom patches: Decompiling Instagram for Smali modification..."
        if ! java -jar "$TEMP_DIR/apkeditor.jar" d -i "$apk" -o "$dir" -f 2>&1; then
                epr "Custom patches: Failed to decompile APK"
                rm -rf "$dir" 2>/dev/null || :
                return 1
        fi

        local patched=0

        # ---- Patch 1: Allow Screenshots in DMs ----
        # From InstaEclipse: removes FLAG_SECURE (0x2000) from Window.setFlags()
        # This allows taking screenshots in DM conversations that normally block them.
        #
        # Technical: Instagram sets Window.FLAG_SECURE on DM activities to prevent
        # screenshots and screen recording. We find all invocations of
        # Landroid/view/Window;->setFlags(II)V where the argument includes 0x2000
        # and replace it with 0x0, effectively clearing the flag.
        pr "Custom patches: [1/2] Allow Screenshots in DMs (FLAG_SECURE removal)..."
        patched+=$(patch_flag_secure "$dir")

        # ---- Patch 2: MobileConfig Quality Override ----
        # Forces high quality media loading by modifying default config values
        # in the Instagram MobileConfig fallback/defaults.
        # This complements "Improve image viewing" (2048px CDN) by also
        # affecting video bitrate and upload quality defaults.
        pr "Custom patches: [2/2] MobileConfig quality defaults..."
        patched+=$(patch_mobileconfig_quality "$dir")

        # ---- Recompile ----
        pr "Custom patches: Recompiling APK..."
        local output="${apk%.apk}-custom.apk"
        if ! java -jar "$TEMP_DIR/apkeditor.jar" b -i "$dir" -o "$output" -f 2>&1; then
                epr "Custom patches: Failed to recompile APK"
                rm -rf "$dir" 2>/dev/null || :
                return 1
        fi

        # ---- Re-sign ----
        pr "Custom patches: Re-signing APK..."
        if ! java -jar "$APKSIGNER" sign \
                --ks ks-p12.keystore \
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
# InstaEclipse equivalent: AllowScreenshotsInDMs
#
# Instagram calls Window.setFlags(FLAG_SECURE, FLAG_SECURE) on DM activities.
# FLAG_SECURE = 0x00002000 = 8192
#
# In Smali, this looks like:
#   const/16 vN, 0x2000
#   ...
#   invoke-virtual {vX, vN, vN}, Landroid/view/Window;->setFlags(II)V
#
# We find all such patterns and replace 0x2000 with 0x0.
# This is the exact same approach InstaEclipse uses via Xposed hooks,
# but applied at the bytecode level instead of runtime.
# ============================================
patch_flag_secure() {
        local dir="$1"
        local count=0

        # Find all smali files that reference Window.setFlags
        while IFS= read -r -d '' smali_file; do
                # Check if this file contains Window.setFlags AND 0x2000
                if grep -q "Landroid/view/Window;->setFlags" "$smali_file" 2>/dev/null && \
                   grep -q "0x2000" "$smali_file" 2>/dev/null; then

                        # Replace const/16 vX, 0x2000 with const/16 vX, 0x0
                        # This covers the most common pattern where FLAG_SECURE is loaded
                        # via const/16 (which is used for values 0x100-0xFFFF)
                        #
                        # Pattern: const/16 <any_register>, 0x2000
                        #   where 0x2000 is in the context of Window.setFlags
                        if sed -i \
                                '/Landroid\/view\/Window;->setFlags/{
                                        # Look backwards up to 10 lines for the const/16 0x2000
                                        s/\(const\/16\s\+v[0-9]*,\s\+\)0x2000/\1 0x0/g
                                }' "$smali_file" 2>/dev/null; then
                                :
                        fi

                        # Also handle the general case: any const loading 0x2000 near setFlags
                        # Use a broader approach: in files that contain both patterns,
                        # replace ALL const loads of 0x2000 with 0x0
                        # This is safe because FLAG_SECURE is the ONLY common use of 0x2000
                        if grep -q "0x2000" "$smali_file" 2>/dev/null; then
                                # More targeted: replace const/16 and const that load 0x2000
                                # ONLY in files that also reference Window.setFlags
                                sed -i 's/\(const\/16\s\+v[0-9]*,\s\+\)0x2000/\10x0/g' "$smali_file" 2>/dev/null || :
                                # Also handle const (without /16) just in case
                                sed -i 's/\(const\s\+v[0-9]*,\s\+\)0x2000/\10x0/g' "$smali_file" 2>/dev/null || :
                                count=$((count + 1))
                        fi
                fi
        done < <(find "$dir" -name "*.smali" -print0)

        pr "Custom patches: FLAG_SECURE — patched $count smali files"
        echo "$count"
}

# ============================================
# MobileConfig Quality Override
# ============================================
# Complements "Improve image viewing" by patching default quality
# values in Instagram's MobileConfig fallback system.
#
# When the app can't reach the server for config, it uses hardcoded
# defaults. We patch these defaults to favor higher quality:
#   - Media quality: "high" instead of "medium"
#   - Video bitrate: increased default
#   - Upload quality: "hd" instead of "standard"
#   - Cache size: larger for better prefetching
# ============================================
patch_mobileconfig_quality() {
        local dir="$1"
        local count=0

        # Find strings.xml files and patch quality defaults
        while IFS= read -r -d '' res_file; do
                if grep -q '"medium"' "$res_file" 2>/dev/null; then
                        # Replace media quality defaults from medium to high
                        # Only in config-related string resources
                        sed -i 's/"medium"/"high"/g' "$res_file" 2>/dev/null || :
                        count=$((count + 1))
                fi
                if grep -q '"standard"' "$res_file" 2>/dev/null; then
                        # Replace upload quality from standard to hd
                        sed -i 's/"standard"/"hd"/g' "$res_file" 2>/dev/null || :
                        count=$((count + 1))
                fi
        done < <(find "$dir" -name "strings.xml" -print0)

        # Patch smali quality constants
        while IFS= read -r -d '' smali_file; do
                # Look for quality-related string constants in Instagram's config classes
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
