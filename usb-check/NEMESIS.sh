#!/system/bin/sh
# leafia-check v3 - READ ONLY diagnostics for the HMG Leafia Plus install.
# Changes nothing on the unit. Writes LEAFIA-CHECK.txt (+ the package log) to the
# USB stick it was started from: the handler runs this as root with cwd = USB root.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
export LD_LIBRARY_PATH=/vendor/lib:/system/lib

PKG=wireless.carplay.aa
PARTS=/data/nemesis/$PKG.parts
LOG=/data/nemesis/$PKG.log
DB=/data/nemesis/packages.db
BAK=/data/nemesis/backup/wireless.projection
OUT=LEAFIA-CHECK.txt
TMP=LEAFIA-CHECK.tmp
WANT_PRODUCT=SG2EV.USA.0000.V015.012.260507
XMLS="/system/etc/permissions/android.hardware.wifi.xml /system/etc/permissions/com.hkmc.software.connectivity.carplay_wireless.xml /system/etc/permissions/com.hkmc.software.connectivity.androidauto_wireless.xml"
FILES="/system/app/HKMC_DiPO.apk /system/app/HKMC_DiPO.odex /system/app/HKMC_GPM.apk /system/app/HKMC_GPM.odex /system/app/HKMC_Navi_ExSL.apk /system/app/HKMC_Navi_ExSL.odex /system/app/Iap2ServerApp.apk /system/app/Iap2ServerApp.odex /system/app/HKMC_BtSettings.apk /system/lib/libautoreceiver_infobank.so"

if [ ! -d /data/nemesis ]; then echo "FAIL: /data/nemesis missing - NEMESIS is not installed"; exit 1; fi
if [ ! -w . ]; then echo "FAIL: stick is not writable at $PWD"; exit 1; fi

md5of() {
    if [ -x /system/bin/md5 ]; then _b=/system/bin/md5
    elif [ -x /system/bin/md5sum ]; then _b=/system/bin/md5sum
    elif [ -x /bin/md5sum ]; then _b=/bin/md5sum
    else return 1; fi
    _l=$("$_b" "$1" 2>/dev/null) || return 1
    case "$_l" in
        *"="*) _o=${_l##* } ;;
        *)     _o=${_l%% *} ;;
    esac
    [ -n "$_o" ] || return 1
    echo "$_o"
}

expected() {
    case "$1" in
        /system/app/HKMC_DiPO.apk)                echo 0b04c9d790dfe80e5d33c3be4f3b3f3b ;;
        /system/app/HKMC_DiPO.odex)               echo 6953fa525b2a2fe4252250f38296c837 ;;
        /system/app/HKMC_GPM.apk)                 echo c62af648f758dcb01a0acb6c2b901ebf ;;
        /system/app/HKMC_GPM.odex)                echo c4f751a36be916e72cf93df0436d63c2 ;;
        /system/app/HKMC_Navi_ExSL.apk)           echo 19559e742b1d21550aa8f0324e8e6d36 ;;
        /system/app/HKMC_Navi_ExSL.odex)          echo 5b55bdee8821d049cedc162b862f64f9 ;;
        /system/app/Iap2ServerApp.apk)            echo fde208439f993986a60396e759797a01 ;;
        /system/app/Iap2ServerApp.odex)           echo f3e22d94150de40f4ed603798358b0e3 ;;
        /system/lib/libautoreceiver_infobank.so) echo 48ee793af8b86052503b8c952b034731 ;;
        /system/app/HKMC_BtSettings.apk)          echo 8c6f5012PREFIX ;;
        *) echo "" ;;
    esac
}

_unverified=0
_changed=0
_stock=0
_prefix=0
_revert_diff=0
_revert_ok=0
_warn=""

# live-vs-snapshot comparison: $1 label, $2 live value, $3 expected value
cmp_live() {
    if [ "$2" = "$3" ]; then
        echo "MATCH    $1"
        _revert_ok=$((_revert_ok + 1))
    else
        echo "DIFFERS  $1  live=[$2] snapshot=[$3]"
        _revert_diff=$((_revert_diff + 1))
    fi
}

{
    echo "NEMESIS leafia-check v3 (read only)"
    echo "date=$(date 2>/dev/null)"
    echo "product=$(getprop ro.build.product)"
    echo "product2=$(getprop ro.build.product2)"
    echo "android=$(getprop ro.build.version.release)"
    echo "nemesis=$([ -x /system/xbin/nemesis ] && echo present || echo missing)"
    echo "hmgapid=$([ -x /system/bin/hmgapid ] && echo present || echo absent)"
    if [ "$(getprop ro.build.product)" != "$WANT_PRODUCT" ]; then
        _warn="product is not $WANT_PRODUCT: the expected hashes below are for that build only"
        echo "WARNING: $_warn"
    fi
    echo

    echo "== package state =="
    if [ -f "$PARTS" ]; then
        echo "parts_file=$PARTS"
        while IFS= read -r _p; do
            [ -n "$_p" ] && echo "part=$_p"
        done < "$PARTS"
    else
        echo "parts_file=absent"
    fi
    echo "app_dir=$([ -d /data/nemesis/apps/$PKG ] && echo present || echo absent)"
    if [ -f "/data/nemesis/apps/$PKG/BUILD" ]; then
        echo "installed_build=$(cat "/data/nemesis/apps/$PKG/BUILD" 2>/dev/null)"
    fi
    if [ -f "$DB" ]; then
        grep "^$PKG|" "$DB" 2>/dev/null | sed 's/^/packages_db=/'
    fi
    echo "addon_projection.cardata=$([ -d /data/nemesis/apps/projection.cardata ] && echo PRESENT-BLOCKS-UNINSTALL || echo absent)"
    echo "backup_dir=$([ -d "$BAK" ] && echo present || echo absent)"
    if [ -d "$BAK" ]; then
        ls -l "$BAK" 2>/dev/null | sed 's/^/  /'
        for _m in saved live restored; do
            [ -f "$BAK/$_m" ] && echo "marker=$_m"
        done
        [ -f "$BAK/saved" ] || { _warn="no $BAK/saved marker: there may be no snapshot to revert from"; echo "WARNING: $_warn"; }
    fi
    echo

    echo "== props =="
    for _k in persist.ium.support persist.wifi.state persist.sys.iap2.wifi persist.sys.iap2.btconnection; do
        echo "getprop $_k=$(getprop "$_k" 2>/dev/null)"
    done
    grep '^persist.ium.support=' /system/build.prop 2>/dev/null | sed 's/^/build.prop /'
    grep '^persist.wifi.state=' /system/build.prop 2>/dev/null | sed 's/^/build.prop /'
    grep '^persist.sys.iap2' /system/build.prop 2>/dev/null | sed 's/^/build.prop /'
    echo "settings_wifi_on=$(settings get global wifi_on 2>/dev/null)"
    echo

    echo "== wifi feature files =="
    for _f in $XMLS; do
        if [ -f "$_f" ]; then
            _h=$(md5of "$_f")
            echo "present $_f ${_h:-hash-failed}"
        else
            echo "absent  $_f"
        fi
    done
    echo

    echo "== file hashes =="
    for _f in $FILES; do
        _want=$(expected "$_f")
        if [ ! -f "$_f" ]; then
            echo "MISSING     $_f"
            _changed=$((_changed + 1))
            continue
        fi
        _got=$(md5of "$_f")
        if [ -z "$_got" ]; then
            echo "HASH-FAIL   $_f"
            _unverified=$((_unverified + 1))
            continue
        fi
        case "$_want" in
            *PREFIX)
                _pre=${_want%PREFIX}
                case "$_got" in
                    "$_pre"*)
                        echo "STOCK-PFX   $_got  $_f  (stock starts $_pre)"
                        _stock=$((_stock + 1))
                        _prefix=$((_prefix + 1))
                        continue ;;
                esac
                echo "CHANGED     $_got  stock starts $_pre  $_f"
                _changed=$((_changed + 1))
                continue ;;
        esac
        if [ -z "$_want" ]; then
            echo "UNVERIFIED  $_got  $_f   (no stock hash known for this file)"
            _unverified=$((_unverified + 1))
            continue
        fi
        if [ "$_got" = "$_want" ]; then
            echo "STOCK       $_got  $_f"
            _stock=$((_stock + 1))
        else
            echo "CHANGED     $_got  stock $_want  $_f"
            _changed=$((_changed + 1))
        fi
    done
    echo "bt_settings_odex=$([ -f /system/app/HKMC_BtSettings.odex ] && echo present || echo absent) (presence only, no stock hash known)"
    echo

    echo "== revert check: live vs Leafia's own stock snapshot =="
    if [ ! -d "$BAK" ]; then
        echo "SKIP: no $BAK - this check needs the snapshot Leafia took at install"
        _unverified=$((_unverified + 1))
    else
        for _f in $XMLS; do
            _sb=$BAK/perm.$(basename "$_f")
            if [ -f "$_sb.absent" ]; then
                if [ -f "$_f" ]; then cmp_live "$_f (snapshot: absent)" present absent; else cmp_live "$_f (snapshot: absent)" absent absent; fi
            elif [ -f "$_sb" ]; then
                _sv=$(md5of "$_sb")
                if [ -f "$_f" ]; then _lv=$(md5of "$_f"); else _lv=absent; fi
                cmp_live "$_f" "$_lv" "$_sv"
            else
                echo "UNKNOWN     $_f (no snapshot entry)"
                _unverified=$((_unverified + 1))
            fi
        done
        for _k in persist.ium.support persist.wifi.state; do
            _sb=$BAK/bp.$_k
            _live=$(grep "^$_k=" /system/build.prop 2>/dev/null | head -n 1)
            if [ -f "$_sb.absent" ]; then
                if [ -z "$_live" ]; then cmp_live "$_k in build.prop (snapshot: absent)" absent absent; else cmp_live "$_k in build.prop (snapshot: absent)" "$_live" absent; fi
            elif [ -f "$_sb" ]; then
                cmp_live "$_k in build.prop" "$_live" "$(cat "$_sb" 2>/dev/null)"
            else
                echo "UNKNOWN     $_k (no snapshot entry)"
                _unverified=$((_unverified + 1))
            fi
        done
        for _k in persist.ium.support persist.wifi.state; do
            _sb=$BAK/gp.$_k
            _live=$(getprop "$_k" 2>/dev/null)
            if [ -f "$_sb.unset" ]; then
                if [ -z "$_live" ]; then cmp_live "getprop $_k (snapshot: unset)" unset unset; else cmp_live "getprop $_k (snapshot: unset)" "$_live" unset; fi
            elif [ -f "$_sb" ]; then
                cmp_live "getprop $_k" "$_live" "$(cat "$_sb" 2>/dev/null)"
            else
                echo "UNKNOWN     getprop $_k (no snapshot entry)"
                _unverified=$((_unverified + 1))
            fi
        done
        if [ -f "$BAK/wifi_on.unset" ]; then
            _v=$(settings get global wifi_on 2>/dev/null)
            case "$_v" in
                null|"") cmp_live "settings wifi_on (snapshot: unset)" absent absent ;;
                *) cmp_live "settings wifi_on (snapshot: unset)" "$_v" absent ;;
            esac
        elif [ -f "$BAK/wifi_on" ]; then
            cmp_live "settings wifi_on" "$(settings get global wifi_on 2>/dev/null)" "$(cat "$BAK/wifi_on" 2>/dev/null)"
        else
            echo "SKIP        settings wifi_on (snapshot unreadable at install)"
        fi
        if [ -f "$BAK/featurexml.path" ]; then
            _fx=$(cat "$BAK/featurexml.path" 2>/dev/null)
            if [ -f "$BAK/featurexml.cfg" ]; then
                if [ -f "$_fx" ]; then _lv=$(md5of "$_fx"); else _lv=absent; fi
                cmp_live "$_fx" "$_lv" "$(md5of "$BAK/featurexml.cfg")"
            else
                echo "UNKNOWN     featurexml snapshot incomplete"
                _unverified=$((_unverified + 1))
            fi
        elif [ -f "$BAK/featurexml.absent" ]; then
            echo "NOTE        snapshot recorded no featurexml.cfg with wireless entries"
        fi
    fi
    echo

    echo "== featurexml.cfg wireless lines =="
    _n=0
    for _x in /system/onebin/*/featurexml.cfg; do
        [ -f "$_x" ] || continue
        _n=$((_n + 1))
        echo "--- $_x"
        grep -i 'wifi' "$_x" 2>/dev/null
        grep -i 'carplay' "$_x" 2>/dev/null
        grep -i 'androidauto' "$_x" 2>/dev/null
        grep -i 'hotspot' "$_x" 2>/dev/null
    done
    [ "$_n" -eq 0 ] && echo "none found (no /system/onebin/*/featurexml.cfg)"
    echo

    echo "== kernel wifi lines =="
    dmesg 2>/dev/null | grep -i 'dhd' | tail -n 8
    echo

    echo "== package log =="
    if [ -f "$LOG" ]; then
        tail -n 40 "$LOG" 2>/dev/null
        if cp -f "$LOG" LEAFIA-CHECK-log.txt 2>/dev/null; then
            echo "copied $LOG to LEAFIA-CHECK-log.txt"
        else
            echo "WARNING: could not copy $LOG to the stick"
            _unverified=$((_unverified + 1))
        fi
    else
        echo "log absent: $LOG"
    fi
    echo
    echo "stock=$_stock prefix_only=$_prefix changed=$_changed unverified=$_unverified"
    echo "revert_match=$_revert_ok revert_differs=$_revert_diff"
} > "$TMP"

if [ "$_revert_diff" -gt 0 ]; then
    _verdict=NOT-REVERTED
elif [ "$_changed" -gt 0 ]; then
    _verdict=NOT-STOCK
elif [ "$_unverified" -gt 0 ]; then
    _verdict=STOCK-BUT-INCOMPLETE
else
    _verdict=ALL-STOCK
fi

{
    echo "verdict=$_verdict"
    [ -n "$_warn" ] && echo "warning=$_warn"
    [ "$_prefix" -gt 0 ] && echo "note=$_prefix file verified by stock-hash prefix only (HKMC_BtSettings.apk: the menu patch recorded a truncated hash)"
    echo "run this before AND after the uninstall. ALL-STOCK is the goal after."
    echo
    cat "$TMP"
} > "$OUT"
rm -f "$TMP"

echo "leafia-check: verdict=$_verdict - wrote $PWD/$OUT"
case "$_verdict" in
    ALL-STOCK) exit 0 ;;
    *) exit 3 ;;
esac
