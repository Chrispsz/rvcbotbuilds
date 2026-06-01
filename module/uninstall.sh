#!/system/bin/sh

MODDIR=${0%/*}
. "$MODDIR/config"

rm -f "/data/adb/rvhc/${MODDIR##*/}.apk"
rmdir "/data/adb/rvhc"

rm -f "/data/adb/post-fs-data.d/$PKG_NAME-uninstall.sh"

# Clean up MetaConfig overrides
if [ "$PKG_NAME" = "com.instagram.instagram" ]; then
        rm -f "/data/data/com.instagram.instagram/files/mobileconfig/mc_overrides.json"
fi
