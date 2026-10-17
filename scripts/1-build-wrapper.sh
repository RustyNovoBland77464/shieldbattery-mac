#!/bin/bash
# Build a Sikarugir Wine wrapper from the published template and engine. Does the same as the
# GUI-only "Sikarugir Creator" app, which isn't needed.
set -euo pipefail
. "$(dirname "$0")/common.sh"

TEMPLATE="${TEMPLATE:-Template-1.0.24}"
ENGINE="${ENGINE:-WS12WineSikarugir11.0_1}"   # Wine 11; list: https://sikarugir-app.github.io/Engines/EngineList.txt

[ -e "$WRAPPER" ] && { echo "$WRAPPER already exists"; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fL -o "$tmp/t.tar.xz" "https://github.com/Sikarugir-App/Template/releases/download/v1.0/$TEMPLATE.tar.xz"
curl -fL -o "$tmp/e.tar.xz" "https://github.com/Sikarugir-App/Engines/releases/download/v1.0/$ENGINE.tar.xz"
tar -xJf "$tmp/t.tar.xz" -C "$tmp"
tar -xJf "$tmp/e.tar.xz" -C "$tmp"
mkdir -p "$(dirname "$WRAPPER")"
mv "$tmp/$TEMPLATE.app" "$WRAPPER"
mv "$tmp/wswine.bundle" "$C/SharedSupport/wine"
xattr -dr com.apple.quarantine "$WRAPPER" 2>/dev/null || true

# Don't link the Windows user folders to ~/Documents etc. When the wrapper is opened from
# Finder, macOS privacy protection (TCC) blocks ~/Documents, which breaks ShieldBattery's
# replay folder. With this off, Documents is a real folder inside the prefix.
plist_set "Symlinks In User Folder" 0

wrun WSS-wineprefixcreate
# Prefix creation still links the user folders to $HOME; replace them with real folders now
# (later launches leave them alone because of the setting above).
for link in "$DRIVE_C"/users/Sikarugir/*; do
    if [ -L "$link" ] && [[ "$(readlink "$link")" == "$HOME"/* ]]; then
        rm "$link" && mkdir "$link"
    fi
done
echo "Wrapper ready: $WRAPPER"
echo "Renderer: DXMT (template default). Keep D3DMETAL=0, since D3DMetal blacks out the ShieldBattery UI."
