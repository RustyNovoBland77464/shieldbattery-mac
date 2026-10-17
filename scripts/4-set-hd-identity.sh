#!/bin/bash
# Enable HD/Remastered (paid content) by reusing the Battle.net offline cookie from a Windows
# install. The cookie is encrypted with base64(SHA1(MachineGuid + C: volume serial)), so the
# prefix is given that Windows machine's MachineGuid and volume serial.
#
# Usage: 4-set-hd-identity.sh <cookie.bin> <MachineGuid> <volume-serial-hex>
#   cookie.bin:  <win>\Users\<you>\AppData\Local\Blizzard Entertainment\ClientSdk\cookie.bin
#   MachineGuid: tools/hive_guid.py <win>\Windows\System32\config\SOFTWARE
#   serial:      low 8 hex digits of the NTFS volume serial of the drive SC:R was installed on
#                (`vol C:` on Windows; on Linux the 16-hex-digit UUID of the mounted partition)
# Check first that the three match: tools/cookie_check.py cookie.bin <guid> <serial-decimal>
set -euo pipefail
. "$(dirname "$0")/common.sh"

cookie="${1:?usage: $0 cookie.bin MachineGuid serial-hex}"
guid="${2:?}"
serial="${3:?}"

wkill
ck="$DRIVE_C/users/Sikarugir/AppData/Local/Blizzard Entertainment/ClientSdk"
mkdir -p "$ck"
cp "$cookie" "$ck/cookie.bin"
# Wine's mount manager reads the drive serial from this file when Wine starts.
printf '%s\n' "$serial" > "$DRIVE_C/.windows-serial"
mkdir -p "$DRIVE_C/sbtools"
printf 'reg add "HKLM\\SOFTWARE\\Microsoft\\Cryptography" /v MachineGuid /t REG_SZ /d %s /f /reg:64\r\n' "$guid" \
    > "$DRIVE_C/sbtools/set-guid.bat"
wrun "$DRIVE_C/sbtools/set-guid.bat" >/dev/null 2>&1
wkill
echo "Set. Check with tools/winsock-tests/hwcheck.c (writes C:\\sbtools\\hwcheck.txt), then open ShieldBattery."
