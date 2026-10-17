# Shared helpers. Source this from the other scripts.
WRAPPER="${WRAPPER:-$HOME/Applications/Sikarugir/ShieldBattery.app}"
C="$WRAPPER/Contents"
PREFIX="$C/SharedSupport/prefix"
DRIVE_C="$PREFIX/drive_c"
PLIST="$C/Info.plist"
SB_DIST="$DRIVE_C/users/Sikarugir/AppData/Local/Programs/shieldbattery-app/resources/game/dist"

# Run a Windows exe/bat inside the wrapper. The launcher sets up the Wine env that a
# bare `wine` call lacks. Arguments after the path are dropped when Wine is already
# running ("secondary run"), so put arguments in a .bat file instead.
wrun() { (cd "$HOME" && "$C/MacOS/wineskinlauncher" "$@"); }

# Stop every Wine process in the wrapper, ShieldBattery included.
wkill() {
    pkill -f "ShieldBattery.exe" 2>/dev/null || true
    sleep 2
    DYLD_FALLBACK_LIBRARY_PATH="$C/Frameworks:/usr/lib" WINEPREFIX="$PREFIX" \
        "$C/SharedSupport/wine/bin/wineserver" -k 2>/dev/null || true
    sleep 1
}

plist_set() { /usr/libexec/PlistBuddy -c "Set :'$1' '$2'" "$PLIST"; }
