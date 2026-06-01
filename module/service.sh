#!/system/bin/sh
MODDIR=${0%/*}
RVPATH=/data/adb/rvhc/${MODDIR##*/}.apk
. "$MODDIR/config"

err() {
        [ ! -f "$MODDIR/err" ] && cp "$MODDIR/module.prop" "$MODDIR/err"
        sed -i "s/^des.*/description=⚠️ Needs reflash: '${1}'/g" "$MODDIR/module.prop"
}

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 1; done
until [ -d "/sdcard/Android" ]; do sleep 1; done
while
        BASEPATH=$(pm path "$PKG_NAME" 2>&1 </dev/null)
        SVCL=$?
        [ $SVCL = 20 ]
do sleep 2; done

run() {
        if [ $SVCL != 0 ]; then
                err "app not installed"
                return
        fi
        sleep 4

        BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
        if [ ! -d "$BASEPATH/lib" ]; then
                err "mount failed. Dont report this, consider using rvmm-zygisk-mount"
                return
        fi
        VERSION=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 versionName) VERSION="${VERSION#*=}"
        if [ "$VERSION" != "$PKG_VER" ] && [ "$VERSION" ]; then
                err "version mismatch (installed:${VERSION}, module:$PKG_VER)"
                return
        fi
        grep "$PKG_NAME" /proc/mounts | while read -r line; do
                mp=${line#* } mp=${mp%% *}
                umount -l "${mp%%\\*}"
        done
        if ! chcon u:object_r:apk_data_file:s0 "$RVPATH"; then
                err "apk not found"
                return
        fi
        mount -o bind "$RVPATH" "$BASEPATH/base.apk"
        am force-stop "$PKG_NAME"
        [ -f "$MODDIR/err" ] && mv -f "$MODDIR/err" "$MODDIR/module.prop"
}

# ============================================
# MetaConfig Override Injection with OTA
# Copies mc_overrides.json into Instagram's
# mobileconfig directory on every boot.
#
# OTA: Checks GitHub for updated config.
# If a newer mc_overrides.json is available,
# downloads and replaces the local copy.
# Survives app updates (re-applied each boot).
# ============================================
OTA_URL="https://raw.githubusercontent.com/Chrispsz/rvcbotbuilds/main/module/mc_overrides.json"
OTA_VERSION_FILE="/data/adb/rvhc/mc_overrides_version"

inject_metaconfig() {
        IG_DATA="/data/data/com.instagram.instagram/files/mobileconfig"
        MC_SRC="$MODDIR/mc_overrides.json"
        MC_DST="$IG_DATA/mc_overrides.json"

        if [ ! -f "$MC_SRC" ]; then
                return
        fi

        # Wait for Instagram data directory to exist
        local retries=0
        while [ ! -d "/data/data/com.instagram.instagram" ] && [ $retries -lt 30 ]; do
                sleep 2
                retries=$((retries + 1))
        done

        if [ ! -d "/data/data/com.instagram.instagram" ]; then
                return
        fi

        # Create mobileconfig directory if needed
        mkdir -p "$IG_DATA"

        # Only copy if file is different or missing
        if [ ! -f "$MC_DST" ] || ! cmp -s "$MC_SRC" "$MC_DST"; then
                cp -f "$MC_SRC" "$MC_DST"

                # Fix ownership to match Instagram's UID/GID
                IG_UID=$(stat -c '%u' /data/data/com.instagram.instagram)
                IG_GID=$(stat -c '%g' /data/data/com.instagram.instagram)
                chown $IG_UID:$IG_GID "$MC_DST"
                chmod 660 "$MC_DST"

                # Fix SELinux context
                chcon u:object_r:app_data_file:s0 "$MC_DST"

                # Restart Instagram to pick up new config
                am force-stop com.instagram.instagram
        fi
}

# ============================================
# OTA Update for mc_overrides.json
# Downloads updated config from GitHub if available.
# Runs in background to avoid delaying boot.
# ============================================
ota_metaconfig() {
        # Only check OTA if we have network and the binary
        if [ ! -f "/system/bin/curl" ] && [ ! -f "/system/bin/wget" ]; then
                return
        fi

        # Wait for network connectivity
        local net_retries=0
        until ping -c 1 -W 3 raw.githubusercontent.com >/dev/null 2>&1 || [ $net_retries -ge 10 ]; do
                sleep 5
                net_retries=$((net_retries + 1))
        done

        if [ $net_retries -ge 10 ]; then
                return
        fi

        # Download OTA config to temp file
        local tmp_file="/data/local/tmp/mc_overrides_ota.json"
        if command -v curl >/dev/null 2>&1; then
                curl -sL --max-time 30 "$OTA_URL" -o "$tmp_file" 2>/dev/null
        elif command -v wget >/dev/null 2>&1; then
                wget -q --timeout=30 -O "$tmp_file" "$OTA_URL" 2>/dev/null
        fi

        # Validate download: must be non-empty JSON
        if [ -f "$tmp_file" ] && [ -s "$tmp_file" ]; then
                # Basic validation: file starts with { and ends with }
                local first_char last_char
                first_char=$(head -c 1 "$tmp_file" 2>/dev/null)
                last_char=$(tail -c 1 "$tmp_file" 2>/dev/null)

                if [ "$first_char" = "{" ] && [ "$last_char" = "}" ]; then
                        # Check if different from current config
                        if ! cmp -s "$tmp_file" "$MODDIR/mc_overrides.json"; then
                                # Update the module's config file
                                cp -f "$tmp_file" "$MODDIR/mc_overrides.json"
                                chcon u:object_r:system_file:s0 "$MODDIR/mc_overrides.json"

                                # Record update timestamp
                                date +%s > "$OTA_VERSION_FILE"

                                # Re-inject the updated config
                                inject_metaconfig
                        fi
                fi
        fi

        # Cleanup
        rm -f "$tmp_file" 2>/dev/null
}

run
inject_metaconfig

# Run OTA check in background (non-blocking)
ota_metaconfig &
