#!/bin/bash
# Install ShieldBattery (download ShieldBattery-setup-*.exe from shieldbattery.net in a browser;
# plain curl gets a 403), patch it for Wine on macOS, and make the wrapper open it.
# Usage: 3-install-shieldbattery.sh ~/Downloads/ShieldBattery-setup-X.Y.Z.exe
set -euo pipefail
. "$(dirname "$0")/common.sh"

installer="${1:?usage: $0 ShieldBattery-setup.exe}"
cp "$installer" "$DRIVE_C/sb-setup.exe"
# The silent installer launches ShieldBattery when it's done, and the launcher only returns
# once that exits, so run it in the background and wait for the files to appear.
wrun "$DRIVE_C/sb-setup.exe" /S >/dev/null 2>&1 &
for _ in $(seq 120); do
    [ -f "$SB_DIST/shieldbattery_64.dll" ] && break
    sleep 2
done
sleep 5
rm -f "$DRIVE_C/sb-setup.exe"
wkill

plist_set "Program Name and Path" "/users/Sikarugir/AppData/Local/Programs/shieldbattery-app/ShieldBattery.exe"
python3 -I "$(dirname "$0")/patch_shieldbattery_wine.py" "$SB_DIST"
echo "Done. Open $WRAPPER to start ShieldBattery."
