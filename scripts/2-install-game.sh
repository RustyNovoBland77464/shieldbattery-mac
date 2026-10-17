#!/bin/bash
# Move a Windows StarCraft: Remastered folder (copied from a Windows install; must contain
# x86/, x86_64/ and Data/) to C:\Program Files (x86)\StarCraft, ShieldBattery's default path.
# Usage: 2-install-game.sh /path/to/StarCraft
set -euo pipefail
. "$(dirname "$0")/common.sh"

src="${1:?usage: $0 /path/to/StarCraft}"
for f in x86/StarCraft.exe x86/ClientSdk.dll x86_64/StarCraft.exe Data; do
    [ -e "$src/$f" ] || { echo "missing $src/$f"; exit 1; }
done
dst="$DRIVE_C/Program Files (x86)/StarCraft"
[ -e "$dst" ] && { echo "$dst already exists"; exit 1; }
mv "$src" "$dst"

# Shortcut to the game's Documents folder (settings, maps, replays) at ~/Games/StarCraft.
mkdir -p "$DRIVE_C/users/Sikarugir/Documents/StarCraft/Maps/Replays" "$HOME/Games"
[ -e "$HOME/Games/StarCraft" ] || ln -s "$DRIVE_C/users/Sikarugir/Documents/StarCraft" "$HOME/Games/StarCraft"
echo "Game installed at $dst"
