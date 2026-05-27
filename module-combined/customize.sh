ui_print ""
ui_print "* RVCBot RevPack Installer"
ui_print "  by Chrispsz"
ui_print ""

# Vol+ = Yes (return 0), Vol- = No (return 1), timeout = Yes (return 0)
_choose() {
	local KEY TIMEOUT=5
	KEY=$(timeout "$TIMEOUT" getevent -lc 16 2>/dev/null | awk '/EV_KEY.*KEY_VOLUME.*DOWN/{print $3; exit}')
	case "$KEY" in
		KEY_VOLUMEUP) return 0 ;;
		KEY_VOLUMEDOWN) return 1 ;;
		*)
			ui_print "  Timeout, instalando..."
			return 0 ;;
	esac
}

if [ "$ARCH" = "arm" ]; then
	ARCH_LIB=armeabi-v7a
elif [ "$ARCH" = "arm64" ]; then
	ARCH_LIB=arm64-v8a
elif [ "$ARCH" = "x86" ]; then
	ARCH_LIB=x86
elif [ "$ARCH" = "x64" ]; then
	ARCH_LIB=x86_64
else abort "ERROR: unsupported arch: ${ARCH}"; fi

set_perm_recursive "$MODPATH/bin" 0 0 0755 0777

pmex() {
	OP=$(pm "$@" 2>&1 </dev/null)
	RET=$?
	echo "$OP"
	return $RET
}

install_app() {
	local APP_DIR="$1"
	unset PKG_NAME PKG_VER MODULE_ARCH
	. "$APP_DIR/config"

	if [ -n "$MODULE_ARCH" ] && [ "$MODULE_ARCH" != "$ARCH" ]; then
		ui_print "* Pulando $PKG_NAME (arch: modulo=$MODULE_ARCH device=$ARCH)"
		return 0
	fi

	ui_print ""
	ui_print "---------------------------------------"
	ui_print "* $PKG_NAME  v$PKG_VER"
	ui_print "  Instalar? (auto-sim em 5s)"
	ui_print "  Vol+ = Sim  |  Vol- = Nao"
	if ! _choose; then
		ui_print "* Pulado: $PKG_NAME"
		return 0
	fi
	ui_print "* Instalando $PKG_NAME..."

	local RVPATH=/data/adb/rvhc/${MODPATH##*/}-${PKG_NAME}.apk
	local BASEPATH INS IS_SYS

	su -M -c grep -F "$PKG_NAME" /proc/mounts | while read -r line; do
		ui_print "* Un-mount $PKG_NAME"
		local mp=${line#* }; mp=${mp%% *}
		su -M -c umount -l "${mp%%\\*}"
	done
	am force-stop "$PKG_NAME"

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
			ui_print "* $PKG_NAME e app de sistema."
			IS_SYS=true
		elif [ ! -f "$APP_DIR/$PKG_NAME.apk" ]; then
			ui_print "* Stock APK nao encontrado"
			local VERSION
			VERSION=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 versionName)
			VERSION="${VERSION#*=}"
			if [ "$VERSION" = "$PKG_VER" ] || [ -z "$VERSION" ]; then
				ui_print "* Pulando instalacao stock"
				INS=false
			else
				abort "ERROR: Versao diferente
			instalado: $VERSION
			modulo:    $PKG_VER
			"
			fi
		elif "${MODPATH:?}/bin/$ARCH/cmpr" "$BASEPATH/base.apk" "$APP_DIR/$PKG_NAME.apk"; then
			ui_print "* $PKG_NAME atualizado"
			INS=false
		fi
	fi

	_install_pkg() {
		if [ ! -f "$APP_DIR/$PKG_NAME.apk" ]; then
			abort "ERROR: Stock $PKG_NAME apk nao encontrado"
		fi
		ui_print "* Atualizando $PKG_NAME para $PKG_VER"
		local install_err=""
		local VERIF1 VERIF2
		VERIF1=$(settings get global verifier_verify_adb_installs)
		VERIF2=$(settings get global package_verifier_enable)
		settings put global verifier_verify_adb_installs 0
		settings put global package_verifier_enable 0
		local SZ SES op
		SZ=$(stat -c "%s" "$APP_DIR/$PKG_NAME.apk")
		for IT in 1 2; do
			if ! SES=$(pmex install-create --user 0 -i com.android.vending -r -d -S "$SZ"); then
				ui_print "ERROR: install-create falhou"
				install_err="$SES"
				break
			fi
			SES=${SES#*[} SES=${SES%]*}
			set_perm "$APP_DIR/$PKG_NAME.apk" 1000 1000 644 u:object_r:apk_data_file:s0
			if ! op=$(pmex install-write -S "$SZ" "$SES" "$PKG_NAME.apk" "$APP_DIR/$PKG_NAME.apk"); then
				ui_print "ERROR: install-write falhou"
				install_err="$op"
				break
			fi
			if ! op=$(pmex install-commit "$SES"); then
				echo >&2 "$op"
				if echo "$op" | grep -q -e INSTALL_FAILED_VERSION_DOWNGRADE -e INSTALL_FAILED_UPDATE_INCOMPATIBLE; then
					ui_print "* Tratando erro de instalacao"
					pmex uninstall-system-updates "$PKG_NAME"
					if ! BASEPATH=$(pmex path "$PKG_NAME"); then
						ui_print "* Limpando dados residuais..."
						pmex uninstall "$PKG_NAME" >/dev/null 2>&1 || true
						continue
					fi
					BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
					if [ "${BASEPATH:1:4}" != data ]; then IS_SYS=true; fi
					if [ "$IS_SYS" = true ]; then
						local SCNM="/data/adb/post-fs-data.d/$PKG_NAME-uninstall.sh"
						if [ -f "$SCNM" ]; then
							ui_print "* Remova o modulo antigo. Reboot e reflash!"
							install_err=" "
							break
						fi
						mkdir -p /data/adb/rvhc/empty /data/adb/post-fs-data.d
						echo "mount -o bind /data/adb/rvhc/empty $BASEPATH" >"$SCNM"
						chmod +x "$SCNM"
						ui_print "* Script de uninstall criado."
						ui_print "* Reboot e reflash o modulo!"
						install_err=" "
						break
					else
						ui_print "* Desinstalando..."
						if ! op=$(pmex uninstall -k --user 0 "$PKG_NAME"); then
							ui_print "$op"
							if [ "$IT" = 2 ]; then
								install_err="ERROR: pm uninstall falhou."
								break
							fi
						fi
						continue
					fi
				fi
				ui_print "ERROR: install-commit falhou"
				install_err="$op"
				break
			fi
			if BASEPATH=$(pmex path "$PKG_NAME"); then
				BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
			else
				install_err="ERROR: instale $PKG_NAME manualmente e reflash"
				break
			fi
			break
		done
		settings put global verifier_verify_adb_installs "$VERIF1"
		settings put global package_verifier_enable "$VERIF2"
		if [ "$install_err" ]; then abort "$install_err"; fi
	}

	if [ "$INS" = true ] && ! _install_pkg; then abort; fi

	local BASEPATHLIB=${BASEPATH}/lib/${ARCH}
	if [ "$INS" = true ] || [ -z "$(ls -A1 "$BASEPATHLIB")" ]; then
		ui_print "* Extraindo native libs para $PKG_NAME"
		if [ ! -d "$BASEPATHLIB" ]; then mkdir -p "$BASEPATHLIB"; else rm -f "$BASEPATHLIB"/* >/dev/null 2>&1 || :; fi
		if ! op=$(unzip -o -j "$APP_DIR/$PKG_NAME.apk" "lib/${ARCH_LIB}/*" -d "$BASEPATHLIB" 2>&1); then
			ui_print "AVISO: falhou extrair native libs para $PKG_NAME"
		else
			set_perm_recursive "${BASEPATH}/lib" 1000 1000 755 755 u:object_r:apk_data_file:s0
		fi
	fi

	ui_print "* Configurando permissoes para $PKG_NAME"
	set_perm "$APP_DIR/base.apk" 1000 1000 644 u:object_r:apk_data_file:s0

	ui_print "* Montando $PKG_NAME"
	mkdir -p /data/adb/rvhc
	mv -f "$APP_DIR/base.apk" "$RVPATH"

	if ! op=$(su -M -c mount -o bind "$RVPATH" "$BASEPATH/base.apk" 2>&1); then
		ui_print "ERROR: Mount falhou para $PKG_NAME!"
		ui_print "$op"
	fi
	am force-stop "$PKG_NAME"
	ui_print "* Otimizando $PKG_NAME"
	cmd package compile -m speed-profile -f "$PKG_NAME"

	if [ "${KSU:-}" ]; then
		local UID
		UID=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 uid)
		UID=${UID#*=} UID=${UID%% *}
		if [ -z "$UID" ]; then
			UID=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 userId)
			UID=${UID#*=} UID=${UID%% *}
		fi
		if [ "$UID" ]; then
			if ! OP=$("${MODPATH:?}/bin/$ARCH/ksu_profile" "$UID" "$PKG_NAME" 2>&1); then
				ui_print "  $OP"
				ui_print "* KernelSU: desative 'Unmount modules' para $PKG_NAME"
			fi
		else
			ui_print "AVISO: UID nao encontrado para $PKG_NAME"
		fi
	fi

	# Auto-detach for this app in RevPack
	if [ -f "$MODPATH/detach" ]; then
		local DBIN="/data/adb/zygisk-detach/detach.bin"
		mkdir -p /data/adb/zygisk-detach/
		if [ -f "/data/adb/modules/zygisk-detach/detach.bin" ]; then
			cp -f "/data/adb/modules/zygisk-detach/detach.bin" "$DBIN"
		fi
		echo "$PKG_NAME" >> "$MODPATH/detach-pack.txt"
		OP=$("$MODPATH/detach" serialize "$MODPATH/detach-pack.txt" "$DBIN" 2>&1) || true
		ui_print "- Auto-Detach: $PKG_NAME adicionado"
	fi

	rm -f "$APP_DIR/$PKG_NAME.apk"
	ui_print "* Feito: $PKG_NAME"
}

APP_COUNT=0
for app_dir in "$MODPATH/apps"/*/; do
	[ -f "$app_dir/config" ] || continue
	APP_COUNT=$((APP_COUNT + 1))
done
ui_print "* Encontrados $APP_COUNT app(s) para instalar"

# Auto-detach: collect all package names first
if [ -f "$MODPATH/detach" ]; then
	: > "$MODPATH/detach-pack.txt"
	for app_dir in "$MODPATH/apps"/*/; do
		[ -f "$app_dir/config" ] || continue
		unset PKG_NAME
		. "$app_dir/config"
		[ -n "${PKG_NAME:-}" ] && echo "$PKG_NAME" >> "$MODPATH/detach-pack.txt"
	done
	DBIN="/data/adb/zygisk-detach/detach.bin"
	mkdir -p /data/adb/zygisk-detach/
	[ -f "/data/adb/modules/zygisk-detach/detach.bin" ] && cp -f "/data/adb/modules/zygisk-detach/detach.bin" "$DBIN"
	OP=$("$MODPATH/detach" serialize "$MODPATH/detach-pack.txt" "$DBIN" 2>&1) || true
	if [ -f "$DBIN" ]; then
		ui_print "✅ Auto-Detach habilitado para todos os apps"
	else
		ui_print "⚠️  Falhou ao criar detach.bin"
	fi
fi

for app_dir in "$MODPATH/apps"/*/; do
	[ -f "$app_dir/config" ] || continue
	install_app "$app_dir"
done

rm -rf "${MODPATH:?}/bin"
ui_print ""
ui_print "* Todos os apps instalados!"
ui_print "  by Chrispsz (github.com/Chrispsz)"
ui_print "  RevPack by thunderkex"
ui_print "  zygisk-detach by j-hc"
ui_print " "
