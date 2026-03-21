#!/system/bin/sh

# ============================================
# RVCBotBuilds Post-FS-Data Script
# Runs after filesystem is mounted
# ============================================

DEBUG_LOG="/sdcard/rvcbot-debug.txt"

debug_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [post-fs-data] $1" >> "$DEBUG_LOG"
}

debug_log "=========================================="
debug_log "POST-FS-DATA EXECUTING"
debug_log "=========================================="

# Check if zygisk-detach directory exists
if [ -d "/data/adb/zygisk-detach" ]; then
    debug_log "zygisk-detach directory exists"

    # Check detach.bin
    if [ -f "/data/adb/zygisk-detach/detach.bin" ]; then
        debug_log "detach.bin exists"
        debug_log "detach.bin size: $(stat -c %s /data/adb/zygisk-detach/detach.bin) bytes"
    else
        debug_log "WARNING: detach.bin NOT found!"
    fi
else
    debug_log "WARNING: zygisk-detach directory does NOT exist!"
fi

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

# Remove Play Store from Magisk denylist if present (alternative method)
if command -v magisk >/dev/null 2>&1; then
    if magisk --denylist status 2>/dev/null | grep -q "enabled"; then
        debug_log "Magisk denylist is enabled"
        magisk --denylist rm com.android.vending 2>/dev/null || :
        debug_log "Removed com.android.vending from denylist"
    fi
fi

# List loaded Zygisk modules (if possible)
debug_log "Checking for Zygisk modules..."
if [ -d "/data/adb/modules" ]; then
    for mod in /data/adb/modules/*/zygisk; do
        if [ -d "$mod" ]; then
            MOD_NAME=$(basename $(dirname "$mod"))
            debug_log "Found Zygisk module: $MOD_NAME"
        fi
    done
fi

debug_log "post-fs-data.sh completed"
