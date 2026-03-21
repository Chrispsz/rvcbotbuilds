#!/system/bin/sh

# zygisk-detach post-fs-data script
# Ensures detach.bin is properly loaded on boot

if [ -f "/data/adb/zygisk-detach/detach.bin" ]; then
    # Ensure zygisk-detach directory exists
    mkdir -p /data/adb/zygisk-detach
    
    # Copy detach.bin to module directory if zygisk module exists
    if [ -d "/data/adb/modules/zygisk-detach" ]; then
        cp -f "/data/adb/zygisk-detach/detach.bin" "/data/adb/modules/zygisk-detach/detach.bin"
    fi
fi

# Remove Play Store from Magisk denylist if present (alternative method)
if command -v magisk >/dev/null 2>&1; then
    if magisk --denylist status 2>/dev/null | grep -q "enabled"; then
        magisk --denylist rm com.android.vending 2>/dev/null || :
    fi
fi
