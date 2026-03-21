#!/system/bin/sh
MODDIR=${0%/*}
RVPATH=/data/adb/rvhc/${MODDIR##*/}.apk
. "$MODDIR/config"

DEBUG_LOG="/data/local/tmp/rvcbot-debug.txt"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [service] $1" >> "$DEBUG_LOG"
}

err() {
        [ ! -f "$MODDIR/err" ] && cp "$MODDIR/module.prop" "$MODDIR/err"
        sed -i "s/^des.*/description=⚠️ Needs reflash: '${1}'/g" "$MODDIR/module.prop"
}

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 1; done
until [ -d "/sdcard/Android" ]; do sleep 1; done

log "=========================================="
log "service.sh running"
log "Package: $PKG_NAME"
log "=========================================="

# Check Zygisk
ZYGISK_ENABLED=false
if [ -f "/data/adb/magisk.db" ]; then
    ZYGISK_SETTING=$(magisk --sqlite "SELECT value FROM settings WHERE key='zygisk'" 2>/dev/null || echo "")
    [ "$ZYGISK_SETTING" = "1" ] && ZYGISK_ENABLED=true
fi
[ -d "/data/adb/modules/zygisk" ] && ZYGISK_ENABLED=true

log "Zygisk enabled: $ZYGISK_ENABLED"

# Check detach.bin
if [ -f "/data/adb/zygisk-detach/detach.bin" ]; then
    log "detach.bin: EXISTS ($(stat -c %s /data/adb/zygisk-detach/detach.bin) bytes)"
else
    log "detach.bin: MISSING"
fi

# Standard module mount logic
while
        BASEPATH=$(pm path "$PKG_NAME" 2>&1 </dev/null)
        SVCL=$?
        [ $SVCL = 20 ]
do sleep 2; done

run() {
        if [ $SVCL != 0 ]; then
                err "app not installed"
                log "ERROR: App not installed"
                return
        fi
        sleep 4

        BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
        if [ ! -d "$BASEPATH/lib" ]; then
                err "mount failed (ROM issue)"
                log "ERROR: mount failed - lib directory not found"
                return
        fi
        VERSION=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 versionName) VERSION="${VERSION#*=}"
        if [ "$VERSION" != "$PKG_VER" ] && [ "$VERSION" ]; then
                err "version mismatch (installed:${VERSION}, module:$PKG_VER)"
                log "WARNING: Version mismatch"
                return
        fi
        grep "$PKG_NAME" /proc/mounts | while read -r line; do
                mp=${line#* } mp=${mp%% *}
                umount -l "${mp%%\\*}"
        done
        if ! chcon u:object_r:apk_data_file:s0 "$RVPATH"; then
                err "apk not found"
                log "ERROR: APK not found"
                return
        fi
        mount -o bind "$RVPATH" "$BASEPATH/base.apk"
        am force-stop "$PKG_NAME"
        [ -f "$MODDIR/err" ] && mv -f "$MODDIR/err" "$MODDIR/module.prop"
        log "Mount successful"
}

run

log "=========================================="
log "VERIFICATION GUIDE:"
log "1. Open Play Store"
log "2. Search for YouTube"
log "3. It should show 'Open' not 'Update'"
log "=========================================="
