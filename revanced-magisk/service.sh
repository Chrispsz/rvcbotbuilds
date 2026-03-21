#!/system/bin/sh
MODDIR=${0%/*}
RVPATH=/data/adb/rvhc/${MODDIR##*/}.apk
. "$MODDIR/config"

# ============================================
# DEBUG LOG FUNCTION
# ============================================
DEBUG_LOG="/sdcard/rvcbot-debug.txt"

debug_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [service] $1" >> "$DEBUG_LOG"
}

err() {
        [ ! -f "$MODDIR/err" ] && cp "$MODDIR/module.prop" "$MODDIR/err"
        sed -i "s/^des.*/description=⚠️ Needs reflash: '${1}'/g" "$MODDIR/module.prop"
}

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 1; done
until [ -d "/sdcard/Android" ]; do sleep 1; done

debug_log "=========================================="
debug_log "SERVICE.SH EXECUTING"
debug_log "=========================================="
debug_log "Boot completed"
debug_log "PKG_NAME: $PKG_NAME"
debug_log "PKG_VER: $PKG_VER"

# Check Zygisk status
ZYGISK_ENABLED=false
if [ -f "/data/adb/magisk.db" ]; then
    ZYGISK_SETTING=$(magisk --sqlite "SELECT value FROM settings WHERE key='zygisk'" 2>/dev/null || echo "")
    if [ "$ZYGISK_SETTING" = "1" ]; then
        ZYGISK_ENABLED=true
    fi
fi

if [ -d "/data/adb/modules/zygisk" ]; then
    ZYGISK_ENABLED=true
fi

debug_log "Zygisk enabled: $ZYGISK_ENABLED"

# Check detach.bin
if [ -f "/data/adb/zygisk-detach/detach.bin" ]; then
    debug_log "detach.bin exists after boot"
    debug_log "detach.bin size: $(stat -c %s /data/adb/zygisk-detach/detach.bin) bytes"
else
    debug_log "WARNING: detach.bin NOT found after boot!"
fi

# Check if Play Store is running
sleep 5
if pgrep -f "com.android.vending" >/dev/null; then
    debug_log "Play Store is running"
else
    debug_log "Play Store is not running yet"
fi

while
        BASEPATH=$(pm path "$PKG_NAME" 2>&1 </dev/null)
        SVCL=$?
        [ $SVCL = 20 ]
do sleep 2; done

run() {
        if [ $SVCL != 0 ]; then
                err "app not installed"
                debug_log "ERROR: App not installed"
                return
        fi
        sleep 4

        BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
        if [ ! -d "$BASEPATH/lib" ]; then
                err "mount failed (ROM issue). Dont report this, consider using rvmm-zygisk-mount."
                debug_log "ERROR: mount failed - lib directory not found"
                return
        fi
        VERSION=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 versionName) VERSION="${VERSION#*=}"
        if [ "$VERSION" != "$PKG_VER" ] && [ "$VERSION" ]; then
                err "version mismatch (installed:${VERSION}, module:$PKG_VER)"
                debug_log "WARNING: Version mismatch - installed: $VERSION, module: $PKG_VER"
                return
        fi
        grep "$PKG_NAME" /proc/mounts | while read -r line; do
                mp=${line#* } mp=${mp%% *}
                umount -l "${mp%%\\*}"
        done
        if ! chcon u:object_r:apk_data_file:s0 "$RVPATH"; then
                err "apk not found"
                debug_log "ERROR: APK not found at $RVPATH"
                return
        fi
        mount -o bind "$RVPATH" "$BASEPATH/base.apk"
        am force-stop "$PKG_NAME"
        [ -f "$MODDIR/err" ] && mv -f "$MODDIR/err" "$MODDIR/module.prop"
        debug_log "Mount successful for $PKG_NAME"
}

run

debug_log "service.sh completed"
debug_log "=========================================="
debug_log "DEBUG SUMMARY"
debug_log "=========================================="
debug_log "Module: $MODDIR"
debug_log "Package: $PKG_NAME"
debug_log "Version: $PKG_VER"
debug_log "Zygisk: $ZYGISK_ENABLED"
debug_log "detach.bin: $([ -f /data/adb/zygisk-detach/detach.bin ] && echo 'EXISTS' || echo 'MISSING')"
debug_log ""
debug_log "If detach.bin EXISTS and Zygisk is ENABLED,"
debug_log "the zygisk .so should hook Play Store."
debug_log ""
debug_log "To verify zygisk-detach is working:"
debug_log "1. Open Play Store"
debug_log "2. Search for YouTube"
debug_log "3. It should show 'Open' instead of 'Update'"
debug_log "=========================================="
