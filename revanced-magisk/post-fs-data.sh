#!/system/bin/sh

# RVCBotBuilds post-fs-data.sh
# Runs after filesystem is mounted

DEBUG_LOG="/data/local/tmp/rvcbot-debug.txt"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [post-fs-data] $1" >> "$DEBUG_LOG"
}

log "Running post-fs-data.sh"

# Check detach.bin
if [ -f "/data/adb/zygisk-detach/detach.bin" ]; then
    log "detach.bin exists ($(stat -c %s /data/adb/zygisk-detach/detach.bin) bytes)"
else
    log "WARNING: detach.bin NOT found"
fi

# Remove Play Store from denylist (helps with Zygisk)
if command -v magisk >/dev/null 2>&1; then
    magisk --denylist rm com.android.vending 2>/dev/null || :
fi

log "post-fs-data.sh complete"
