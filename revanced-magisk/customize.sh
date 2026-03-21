. "$MODPATH/config"

# ============================================
# DEBUG LOG FUNCTION
# ============================================
DEBUG_LOG="/sdcard/rvcbot-debug.txt"
debug_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$DEBUG_LOG"
}

# Initialize debug log
echo "========================================" > "$DEBUG_LOG"
echo "RVCBotBuilds Auto-Detach Debug Log" >> "$DEBUG_LOG"
echo "========================================" >> "$DEBUG_LOG"
debug_log "Starting installation..."
debug_log "MODPATH: $MODPATH"
debug_log "ARCH: $ARCH"
debug_log "PKG_NAME: $PKG_NAME"
debug_log "PKG_VER: $PKG_VER"

ui_print ""
if [ -n "$MODULE_ARCH" ] && [ "$MODULE_ARCH" != "$ARCH" ]; then
        debug_log "ERROR: Architecture mismatch - Device: $ARCH, Module: $MODULE_ARCH"
        abort "ERROR: Wrong arch
Your device: $ARCH
Module: $MODULE_ARCH"
fi

# ============================================
# ARCHITECTURE MAPPING
# ============================================
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
        BIN_ARCH=x64
else
        debug_log "ERROR: Unknown architecture: $ARCH"
        abort "ERROR: unreachable: ${ARCH}"
fi

RVPATH=/data/adb/rvhc/${MODPATH##*/}.apk
debug_log "ARCH_LIB: $ARCH_LIB"
debug_log "ZYGISK_ARCH: $ZYGISK_ARCH"
debug_log "BIN_ARCH: $BIN_ARCH"

# Check bin folder structure
debug_log "Bin folder contents:"
ls -la "$MODPATH/bin/" >> "$DEBUG_LOG" 2>&1
debug_log "Bin/$BIN_ARCH contents:"
ls -la "$MODPATH/bin/$BIN_ARCH/" >> "$DEBUG_LOG" 2>&1

# Check zygisk folder
debug_log "Zygisk folder contents:"
ls -la "$MODPATH/zygisk/" >> "$DEBUG_LOG" 2>&1

set_perm_recursive "$MODPATH/bin" 0 0 0755 0777

# ============================================
# ZYGISK DETECTION
# ============================================
ZYGISK_ENABLED=false
ZYGISK_MODE=""

# Method 1: Check Magisk Zygisk
if [ -f "/data/adb/magisk.db" ]; then
        ZYGISK_SETTING=$(magisk --sqlite "SELECT value FROM settings WHERE key='zygisk'" 2>/dev/null || echo "")
        if [ "$ZYGISK_SETTING" = "1" ]; then
                ZYGISK_ENABLED=true
                ZYGISK_MODE="Magisk Zygisk"
        fi
fi

# Method 2: Check Zygisk module folder (for KernelSU with Zygisk)
if [ "$ZYGISK_ENABLED" = false ] && [ -d "/data/adb/modules/zygisk" ]; then
        ZYGISK_ENABLED=true
        ZYGISK_MODE="KernelSU Zygisk Module"
fi

# Method 3: Check Zygisk flag file
if [ "$ZYGISK_ENABLED" = false ] && [ -f "/data/adb/zygisk_enabled" ]; then
        ZYGISK_ENABLED=true
        ZYGISK_MODE="Zygisk Flag File"
fi

# Method 4: Check if Magisk has denylist (alternative)
if [ "$ZYGISK_ENABLED" = false ]; then
        if magisk --denylist status 2>/dev/null | grep -q "enabled"; then
                ZYGISK_MODE="Magisk DenyList (not Zygisk)"
        fi
fi

debug_log "Zygisk enabled: $ZYGISK_ENABLED"
debug_log "Zygisk mode: $ZYGISK_MODE"

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
        debug_log "WARNING: Zygisk not enabled, auto-detach will NOT work"
else
        ui_print "✅ Zygisk detected: $ZYGISK_MODE"
        ui_print ""
        debug_log "Zygisk detected successfully"
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
        elif "${MODPATH:?}/bin/$BIN_ARCH/cmpr" "$BASEPATH/base.apk" "$MODPATH/$PKG_NAME.apk"; then
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

# ============================================
# AUTO-DETACH SETUP (ZYGISK)
# ============================================
ui_print ""
ui_print "=========================================="
ui_print "  Setting up Auto-Detach (Zygisk)"
ui_print "=========================================="

DETACH_SUCCESS=false

if [ "$ZYGISK_ENABLED" = true ]; then
        debug_log "Starting auto-detach setup..."

        # Create zygisk-detach directory
        mkdir -p /data/adb/zygisk-detach
        debug_log "Created /data/adb/zygisk-detach directory"

        # Check if detach binary exists
        DETACH_BIN="$MODPATH/bin/$BIN_ARCH/detach"
        debug_log "Looking for detach binary at: $DETACH_BIN"

        if [ -f "$DETACH_BIN" ]; then
                debug_log "Detatch binary found!"
                chmod +x "$DETACH_BIN"

                # Create detach.txt with package name
                DETACH_TXT="$MODPATH/detach.txt"
                echo "$PKG_NAME" > "$DETACH_TXT"
                debug_log "Created detach.txt with: $PKG_NAME"
                cat "$DETACH_TXT" >> "$DEBUG_LOG"

                # Set target detach.bin path
                DBIN="/data/adb/zygisk-detach/detach.bin"

                # Run the detach binary to create detach.bin
                debug_log "Running: $DETACH_BIN serialize $DETACH_TXT $DBIN"

                # Execute and capture output
                SERIALIZE_OUTPUT=$("$DETACH_BIN" serialize "$DETACH_TXT" "$DBIN" 2>&1)
                SERIALIZE_RET=$?

                debug_log "Serialize return code: $SERIALIZE_RET"
                debug_log "Serialize output: $SERIALIZE_OUTPUT"

                if [ -f "$DBIN" ]; then
                        DETACH_SUCCESS=true
                        debug_log "detach.bin created successfully!"
                        debug_log "detach.bin location: $DBIN"
                        debug_log "detach.bin size: $(stat -c %s "$DBIN") bytes"
                        debug_log "detach.bin permissions: $(stat -c %a "$DBIN")"
                        debug_log "detach.bin contents (hex):"
                        xxd "$DBIN" | head -5 >> "$DEBUG_LOG"

                        # Set proper permissions
                        chmod 644 "$DBIN"
                        chown root:root "$DBIN"
                        debug_log "Set permissions on detach.bin"
                else
                        debug_log "ERROR: detach.bin was NOT created!"
                        debug_log "Checking if zygisk-detach directory exists..."
                        ls -la /data/adb/zygisk-detach/ >> "$DEBUG_LOG"
                fi
        else
                debug_log "ERROR: Detach binary NOT found at $DETACH_BIN"
                debug_log "Available binaries in bin folder:"
                find "$MODPATH/bin" -type f -name "detach" >> "$DEBUG_LOG"
        fi

        # Copy zygisk .so to proper location for this module
        # The .so should stay in zygisk/ folder for Zygisk to load
        if [ -f "$MODPATH/zygisk/$ZYGISK_ARCH.so" ]; then
                debug_log "Zygisk .so found: $MODPATH/zygisk/$ZYGISK_ARCH.so"
                chmod 644 "$MODPATH/zygisk/$ZYGISK_ARCH.so"
                debug_log "Zygisk .so permissions set"
        else
                debug_log "WARNING: Zygisk .so NOT found for architecture $ZYGISK_ARCH"
                debug_log "Available .so files:"
                ls -la "$MODPATH/zygisk/" >> "$DEBUG_LOG"
        fi

        ui_print ""
        if [ "$DETACH_SUCCESS" = true ]; then
                ui_print "✅ $PKG_NAME added to detach list"
                ui_print "   Play Store updates will be blocked"
        else
                ui_print "⚠️  Failed to create detach.bin"
                ui_print "   Check /sdcard/rvcbot-debug.txt for details"
        fi
else
        ui_print "⚠️  Skipping auto-detach (Zygisk not enabled)"
        debug_log "Skipped auto-detach setup - Zygisk not enabled"
fi

# ============================================
# KERNELSU SUPPORT
# ============================================
if [ "$KSU" ]; then
        debug_log "KernelSU detected"
        UID=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 uid)
        UID=${UID#*=} UID=${UID%% *}
        if [ -z "$UID" ]; then
                UID=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 userId)
                UID=${UID#*=} UID=${UID%% *}
        fi
        if [ "$UID" ]; then
                if ! OP=$("${MODPATH:?}/bin/$BIN_ARCH/ksu_profile" "$UID" "$PKG_NAME" 2>&1); then
                        ui_print "  $OP"
                        ui_print "* Because you are using a fork of KernelSU, "
                        ui_print "  you need to go to your root manager app and"
                        ui_print "  disable 'Unmount modules' option for $PKG_NAME"
                fi
                debug_log "KernelSU profile configured for UID: $UID"
        else
                ui_print "ERROR: UID could not be found for $PKG_NAME"
                dumpsys package "$PKG_NAME" >&2
                debug_log "ERROR: Could not find UID for $PKG_NAME"
        fi
fi

# ============================================
# CLEANUP
# ============================================
# Remove bin folder (detach binary no longer needed after creating detach.bin)
rm -rf "${MODPATH:?}/bin" "$MODPATH/$PKG_NAME.apk"

ui_print ""
ui_print "=========================================="
ui_print "  Installation Complete!"
ui_print "=========================================="
if [ "$ZYGISK_ENABLED" = true ] && [ "$DETACH_SUCCESS" = true ]; then
        ui_print ""
        ui_print "✅ Auto-Detach: ENABLED"
        ui_print "   Play Store cannot update this app"
        ui_print ""
        ui_print "   Debug log saved to:"
        ui_print "   /sdcard/rvcbot-debug.txt"
else
        ui_print ""
        ui_print "⚠️  Auto-Detach: DISABLED"
        if [ "$ZYGISK_ENABLED" = false ]; then
                ui_print "   Reason: Zygisk not enabled"
        else
                ui_print "   Reason: Failed to create detach.bin"
        fi
        ui_print "   Disable auto-update in Play Store manually"
fi
ui_print ""
ui_print "* Done"
ui_print "  by j-hc (github.com/j-hc)"
ui_print "  RVCBotBuilds fork with Auto-Detach"
ui_print " "

# ============================================
# FINAL DEBUG INFO
# ============================================
debug_log "=========================================="
debug_log "INSTALLATION COMPLETE"
debug_log "=========================================="
debug_log "Zygisk enabled: $ZYGISK_ENABLED"
debug_log "Detach success: $DETACH_SUCCESS"
debug_log "Module path: $MODPATH"
debug_log "Final module contents:"
ls -la "$MODPATH/" >> "$DEBUG_LOG"
debug_log "zygisk-detach directory:"
ls -la /data/adb/zygisk-detach/ >> "$DEBUG_LOG"
