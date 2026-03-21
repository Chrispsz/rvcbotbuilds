. "$MODPATH/config"

ui_print ""
if [ -n "$MODULE_ARCH" ] && [ "$MODULE_ARCH" != "$ARCH" ]; then
        abort "ERROR: Wrong arch
Your device: $ARCH
Module: $MODULE_ARCH"
fi

if [ "$ARCH" = "arm" ]; then
        ARCH_LIB=armeabi-v7a
        ZYGISK_ARCH=armeabi-v7a
        BIN_ARCH=arm
elif [ "$ARCH" = "arm64" ]; then
        ARCH_LIB=arm64-v8a
        ZYGISK_ARCH=arm64-v8a
        BIN_ARCH=arm64
elif [ "$ARCH" = "x86" ]; then
        ARCH_LIB=x86
        ZYGISK_ARCH=x86
        BIN_ARCH=x86
elif [ "$ARCH" = "x64" ]; then
        ARCH_LIB=x86_64
        ZYGISK_ARCH=x86_64
        BIN_ARCH=x86_64
else abort "ERROR: unreachable: ${ARCH}"; fi
RVPATH=/data/adb/rvhc/${MODPATH##*/}.apk

set_perm_recursive "$MODPATH/bin" 0 0 0755 0777

# Check Zygisk status
ZYGISK_ENABLED=false
if [ -d "/data/adb/modules/zygisk" ] || [ -f "/data/adb/zygisk_enabled" ]; then
        ZYGISK_ENABLED=true
fi

# Also check Magisk DenyList (alternative to Zygisk)
if [ -f "/data/adb/magisk.db" ]; then
        if magisk --denylist status 2>/dev/null | grep -q "enabled"; then
                ZYGISK_ENABLED=true
        fi
fi

ui_print "=========================================="
ui_print "  RVCBotBuilds - ReVanced with Auto-Detach"
ui_print "=========================================="
ui_print ""

if [ "$ZYGISK_ENABLED" = false ]; then
        ui_print "⚠️  WARNING: Zygisk is NOT enabled!"
        ui_print "    Auto-detach will NOT work without Zygisk."
        ui_print "    "
        ui_print "    To enable Zygisk:"
        ui_print "    1. Open Magisk/KernelSU app"
        ui_print "    2. Go to Settings"
        ui_print "    3. Enable 'Zygisk' option"
        ui_print "    4. Reboot device"
        ui_print "    5. Reinstall this module"
        ui_print ""
        ui_print "    Alternatively, use zygisk-detach module separately"
        ui_print "    or disable auto-update in Play Store manually."
        ui_print ""
fi

if su -M -c true >/dev/null 2>/dev/null; then
        alias mm='su -M -c'
else alias mm='nsenter -t1 -m'; fi

mm grep -F "$PKG_NAME" /proc/mounts | while read -r line; do
        ui_print "* Un-mount"
        mp=${line#* } mp=${mp%% *}
        mm umount -l "${mp%%\\*}"
done
am force-stop "$PKG_NAME"

pmex() {
        OP=$(pm "$@" 2>&1 </dev/null)
        RET=$?
        echo "$OP"
        return $RET
}

if ! pmex path "$PKG_NAME" >&2; then
        if pmex install-existing "$PKG_NAME" >&2; then
                pmex uninstall-system-updates "$PKG_NAME"
        fi
fi

IS_SYS=false
INS=true
if BASEPATH=$(pmex path "$PKG_NAME"); then
        echo >&2 "'$BASEPATH'"
        BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
        if [ "${BASEPATH:1:4}" != data ]; then
                ui_print "* $PKG_NAME is a system app."
                IS_SYS=true
        elif [ ! -f "$MODPATH/$PKG_NAME.apk" ]; then
                ui_print "* Stock $PKG_NAME APK was not found"
                VERSION=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 versionName) VERSION="${VERSION#*=}"
                if [ "$VERSION" = "$PKG_VER" ] || [ -z "$VERSION" ]; then
                        ui_print "* Skipping stock installation"
                        INS=false
                else
                        abort "ERROR: Version mismatch
                        installed: $VERSION
                        module:    $PKG_VER
                        "
                fi
        elif "${MODPATH:?}/bin/$ARCH/cmpr" "$BASEPATH/base.apk" "$MODPATH/$PKG_NAME.apk"; then
                ui_print "* $PKG_NAME is up-to-date"
                INS=false
        fi
fi

install() {
        if [ ! -f "$MODPATH/$PKG_NAME.apk" ]; then
                abort "ERROR: Stock $PKG_NAME apk was not found"
        fi
        ui_print "* Updating $PKG_NAME to $PKG_VER"
        install_err=""
        VERIF1=$(settings get global verifier_verify_adb_installs)
        VERIF2=$(settings get global package_verifier_enable)
        settings put global verifier_verify_adb_installs 0
        settings put global package_verifier_enable 0
        SZ=$(stat -c "%s" "$MODPATH/$PKG_NAME.apk")
        for IT in 1 2; do
                if ! SES=$(pmex install-create --user 0 -i com.android.vending -r -d -S "$SZ"); then
                        ui_print "ERROR: install-create failed"
                        install_err="$SES"
                        break
                fi
                SES=${SES#*[} SES=${SES%]*}
                set_perm "$MODPATH/$PKG_NAME.apk" 1000 1000 644 u:object_r:apk_data_file:s0
                if ! op=$(pmex install-write -S "$SZ" "$SES" "$PKG_NAME.apk" "$MODPATH/$PKG_NAME.apk"); then
                        ui_print "ERROR: install-write failed"
                        install_err="$op"
                        break
                fi
                if ! op=$(pmex install-commit "$SES"); then
                        ui_print "$op"
                        if echo "$op" | grep -q -e INSTALL_FAILED_VERSION_DOWNGRADE -e INSTALL_FAILED_UPDATE_INCOMPATIBLE; then
                                ui_print "* Handling install error"
                                pmex uninstall-system-updates "$PKG_NAME"
                                if BASEPATH=$(pmex path "$PKG_NAME"); then
                                        BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
                                        if [ "${BASEPATH:1:4}" != data ]; then IS_SYS=true; fi
                                fi
                                if [ "$IS_SYS" = true ]; then
                                        SCNM="/data/adb/post-fs-data.d/$PKG_NAME-uninstall.sh"
                                        if [ -f "$SCNM" ]; then
                                                ui_print "* Remove the old module. Reboot and reflash!"
                                                ui_print ""
                                                install_err=" "
                                                break
                                        fi
                                        mkdir -p /data/adb/rvhc/empty /data/adb/post-fs-data.d
                                        echo "mount -o bind /data/adb/rvhc/empty $BASEPATH" >"$SCNM"
                                        chmod +x "$SCNM"
                                        ui_print "* Created the uninstall script."
                                        ui_print ""
                                        ui_print "* Reboot and reflash the module!"
                                        install_err=" "
                                        break
                                else
                                        ui_print "* Uninstalling..."
                                        if ! op=$(pmex uninstall -k --user 0 "$PKG_NAME"); then
                                                ui_print "$op"
                                                if [ $IT = 2 ]; then
                                                        install_err="ERROR: pm uninstall failed."
                                                        break
                                                fi
                                        fi
                                        continue
                                fi
                        fi
                        ui_print "ERROR: install-commit failed"
                        install_err="$op"
                        break
                fi
                if BASEPATH=$(pmex path "$PKG_NAME"); then
                        BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
                else
                        install_err=" "
                        break
                fi
                break
        done
        settings put global verifier_verify_adb_installs "$VERIF1"
        settings put global package_verifier_enable "$VERIF2"
        if [ "$install_err" ]; then
                ui_print "$install_err"
                abort "ERROR: disable the module, reboot, install $PKG_NAME manually and reflash again"
        fi
}
if [ $INS = true ] && ! install; then abort; fi
BASEPATHLIB=${BASEPATH}/lib/${ARCH}
if [ $INS = true ] || [ -z "$(ls -A1 "$BASEPATHLIB")" ]; then
        ui_print "* Extracting native libs"
        if [ ! -d "$BASEPATHLIB" ]; then mkdir -p "$BASEPATHLIB"; else rm -f "$BASEPATHLIB"/* >/dev/null 2>&1 || :; fi
        if ! op=$(unzip -o -j "$MODPATH/$PKG_NAME.apk" "lib/${ARCH_LIB}/*" -d "$BASEPATHLIB" 2>&1); then
                ui_print "ERROR: extracting native libs failed"
                abort "$op"
        fi
        set_perm_recursive "${BASEPATH}/lib" 1000 1000 755 755 u:object_r:apk_data_file:s0
fi

ui_print "* Setting Permissions"
set_perm "$MODPATH/base.apk" 1000 1000 644 u:object_r:apk_data_file:s0

ui_print "* Mounting $PKG_NAME"
mkdir -p "/data/adb/rvhc"
RVPATH=/data/adb/rvhc/${MODPATH##*/}.apk
mv -f "$MODPATH/base.apk" "$RVPATH"

if ! op=$(mm mount -o bind "$RVPATH" "$BASEPATH/base.apk" 2>&1); then
        ui_print "ERROR: Mount failed!"
        ui_print "$op"
fi
am force-stop "$PKG_NAME"
ui_print "* Optimizing $PKG_NAME"

cmd package compile -m speed-profile -f "$PKG_NAME"
# nohup cmd package compile -m speed-profile -f "$PKG_NAME" >/dev/null 2>&1

# Setup Auto-Detach for Zygisk
if [ "$ZYGISK_ENABLED" = true ]; then
        ui_print ""
        ui_print "=========================================="
        ui_print "  Setting up Auto-Detach (Zygisk)"
        ui_print "=========================================="
        
        mkdir -p /data/adb/zygisk-detach
        
        # Create detach.txt with package name
        echo "$PKG_NAME" > "$MODPATH/detach.txt"
        
        # Generate detach.bin using the detach binary
        if [ -f "$MODPATH/bin/$BIN_ARCH/detach" ]; then
                chmod +x "$MODPATH/bin/$BIN_ARCH/detach"
                DBIN="/data/adb/zygisk-detach/detach.bin"
                
                # Preserve existing detach.bin if it exists
                if [ -f "/data/adb/zygisk-detach/detach.bin" ]; then
                        # Merge with existing packages
                        cp -f "/data/adb/zygisk-detach/detach.bin" "$DBIN.tmp"
                        "$MODPATH/bin/$BIN_ARCH/detach" merge "$MODPATH/detach.txt" "$DBIN.tmp" "$DBIN" 2>/dev/null || \
                        "$MODPATH/bin/$BIN_ARCH/detach" serialize "$MODPATH/detach.txt" "$DBIN" 2>/dev/null
                else
                        "$MODPATH/bin/$BIN_ARCH/detach" serialize "$MODPATH/detach.txt" "$DBIN" 2>/dev/null
                fi
                
                if [ -f "$DBIN" ]; then
                        ui_print "* $PKG_NAME added to detach list"
                        ui_print "* Play Store updates blocked for this app"
                else
                        ui_print "* Warning: Could not create detach.bin"
                        ui_print "* Auto-detach may not work"
                fi
        else
                ui_print "* Warning: detach binary not found for $BIN_ARCH"
                ui_print "* Auto-detach will not work"
        fi
        
        ui_print ""
fi

# KernelSU support
if [ "$KSU" ]; then
        UID=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 uid)
        UID=${UID#*=} UID=${UID%% *}
        if [ -z "$UID" ]; then
                UID=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 userId)
                UID=${UID#*=} UID=${UID%% *}
        fi
        if [ "$UID" ]; then
                if ! OP=$("${MODPATH:?}/bin/$ARCH/ksu_profile" "$UID" "$PKG_NAME" 2>&1); then
                        ui_print "  $OP"
                        ui_print "* Because you are using a fork of KernelSU, "
                        ui_print "  you need to go to your root manager app and"
                        ui_print "  disable 'Unmount modules' option for $PKG_NAME"
                fi
        else
                ui_print "ERROR: UID could not be found for $PKG_NAME"
                dumpsys package "$PKG_NAME" >&2
        fi
fi

rm -rf "${MODPATH:?}/bin" "$MODPATH/$PKG_NAME.apk"

ui_print ""
ui_print "=========================================="
ui_print "  Installation Complete!"
ui_print "=========================================="
if [ "$ZYGISK_ENABLED" = true ]; then
        ui_print ""
        ui_print "✅ Auto-Detach: ENABLED"
        ui_print "   Play Store cannot update this app"
else
        ui_print ""
        ui_print "⚠️  Auto-Detach: DISABLED (no Zygisk)"
        ui_print "   Disable auto-update in Play Store manually"
fi
ui_print ""
ui_print "* Done"
ui_print "  by j-hc (github.com/j-hc)"
ui_print "  RVCBotBuilds fork with Auto-Detach"
ui_print " "
