# ShieldBattery on macOS (Apple Silicon)

Run [ShieldBattery](https://shieldbattery.net), the community ladder client for StarCraft:
Remastered, on an Apple Silicon Mac using Wine. Online games against other players and HD
graphics both work.

Unofficial and not affiliated with ShieldBattery or Blizzard. ShieldBattery only supports
Windows; you use this at your own risk.

**Tested on** an M5 Pro running macOS 26.4, ShieldBattery 12.2.1 and 12.3.0, and StarCraft: Remastered build 13515.

| Feature | Status |
|---|---|
| ShieldBattery client (login, chat, lobbies, maps) | works |
| Games against the computer | works |
| Online games against other players | works (needs patch 2) |
| HD graphics and skins | works if you own them (see [HD graphics](#hd-graphics-optional)) |
| Replays | work |

## How it works

ShieldBattery is a Windows app that launches the **Windows** build of StarCraft: Remastered
and injects its own code into it, so the native Mac version of the game can't be used. Both run
inside a [Sikarugir](https://github.com/Sikarugir-App/Sikarugir) Wine wrapper, with DXMT
translating Direct3D 11 to Metal. Battle.net isn't needed: ShieldBattery starts the game
directly.

Two bugs stop ShieldBattery from working under Wine on macOS. `scripts/patch_shieldbattery_wine.py`
patches both in ShieldBattery's game DLLs; [What gets patched](#what-gets-patched) explains them.

## Requirements

- An Apple Silicon Mac with [Rosetta 2](https://support.apple.com/en-us/102527) installed
  (`softwareupdate --install-rosetta`) and [Homebrew](https://brew.sh).
- The **Windows** StarCraft: Remastered game files. Copy the whole `StarCraft` folder from a
  Windows install (it has `x86\`, `x86_64\` and `Data\`, about 5.5 GB). The free edition is enough.
- A ShieldBattery account.
- Python 3 (comes with the Xcode Command Line Tools).

## Setup

Clone this repo and run the scripts from its root. By default the wrapper goes to
`~/Applications/Sikarugir/ShieldBattery.app`; set `WRAPPER=/other/path.app` to change that.

**1. Build the Wine wrapper** (downloads about 270 MB):

```bash
./scripts/1-build-wrapper.sh
```

This downloads the Sikarugir wrapper template and a Wine 11 engine and creates a Windows 10
prefix. You don't need the Sikarugir Creator app.

**2. Add the game files:**

```bash
./scripts/2-install-game.sh /path/to/StarCraft
```

This moves the folder to `C:\Program Files (x86)\StarCraft`, where ShieldBattery looks by
default, and creates `~/Games/StarCraft`, a shortcut to the game's settings, maps and
replays.

**3. Install ShieldBattery.** Download the installer from
[shieldbattery.net](https://shieldbattery.net) in your browser, then:

```bash
./scripts/3-install-shieldbattery.sh ~/Downloads/ShieldBattery-setup-*.exe
```

This installs it silently, applies the patches and sets the wrapper to open ShieldBattery.

**4. Play:** open `~/Applications/Sikarugir/ShieldBattery.app` and log in.

### Updating ShieldBattery

ShieldBattery's auto-updater **can't work under Wine**. It downloads the update, then tries to
check the installer's signature with PowerShell, which Wine only provides as an empty stub. The
log shows `Error downloading update: SyntaxError: Unexpected end of JSON input`, and you're
stuck on the old version. To update, install the new version by hand over the old one (your
login and settings are kept), which also re-applies the patches:

1. Find the current version on line 1 of <https://cdn.shieldbattery.net/app/latest.yml>.
2. Download `https://cdn.shieldbattery.net/app/ShieldBattery-setup-<version>.exe`. Optionally,
   compare its SHA-512 (`shasum -a 512 file | cut -d' ' -f1 | xxd -r -p | base64`) with
   the one in `latest.yml`.
3. Run `./scripts/3-install-shieldbattery.sh ShieldBattery-setup-<version>.exe`.

If games stick at "Launching game…" or online games fail, the patches are probably missing.
Re-run them (safe to run any time):

```bash
python3 scripts/patch_shieldbattery_wine.py
```

## HD graphics (optional)

HD graphics and skins you've bought are read from Battle.net's offline license file,
`cookie.bin`. Instead of running Battle.net under Wine, you copy that file from a Windows
PC where you've played SC:R through Battle.net, and make the Wine prefix look like that PC.
The file is encrypted with a key derived from the PC's **MachineGuid** and the **volume serial
number** of the drive the game is installed on.

You need three things from the Windows PC:

| What | Where |
|---|---|
| `cookie.bin` | `%LOCALAPPDATA%\Blizzard Entertainment\ClientSdk\cookie.bin` |
| MachineGuid | in PowerShell: `(Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Cryptography).MachineGuid` |
| Volume serial | `vol C:` (or the game's drive letter) prints e.g. `1A2B-3C4D`; use `1a2b3c4d` |

If you only have the Windows disk and not a running Windows, `tools/hive_guid.py` reads the
MachineGuid from `Windows/System32/config/SOFTWARE`. On Linux, the volume serial is the last
8 hex digits of the NTFS partition's UUID (`lsblk -o NAME,UUID`).

Check that the three match before changing anything. The script prints `MATCH` for the
correct serial:

```bash
python3 tools/cookie_check.py cookie.bin <MachineGuid> $((16#1a2b3c4d))
```

Then install them into the prefix. This quits ShieldBattery if it's running:

```bash
./scripts/4-set-hd-identity.sh cookie.bin <MachineGuid> 1a2b3c4d
```

The cookie works even after its expiry date, because ShieldBattery handles that itself. If HD
stops working, play once through Battle.net on Windows and copy the new `cookie.bin`.

## What gets patched

### 1. `sb_init_64.dll` won't load: the game hangs at "Launching game…"

The game log (see [Troubleshooting](#troubleshooting)) shows
`Unable to load sb_init.dll: Os { code: 1114 }`. That DLL's entry point is a single `ret`
instruction, so whether it loads depends on whatever happens to be in a CPU register. Windows
leaves a non-zero value there, so it loads by luck; Wine leaves 0, so it fails. The patch
sets the entry point to 0, which means "no entry point". This affects Wine on Linux too.

### 2. Online games: `binding the client UDP socket failed (os error 10022)`

ShieldBattery's online code opens an IPv6 socket that also carries IPv4 traffic, and tries to
set two IPv4-only options on it (`IP_DONTFRAGMENT`, `IP_PKTINFO`). Linux accepts that, but
**macOS rejects it** and Wine reports the error as `WSAEINVAL` (10022). The networking library
only skips the error codes for "not supported", so the connection fails. The patch makes it
skip 10022 at those two places too, so both options are left off and the connection
works normally. The test programs in `tools/winsock-tests/` show the failing calls and the
working IPv4 round trip.

The patcher finds both places by byte pattern rather than fixed addresses, so it should
keep working across ShieldBattery updates. It refuses to patch anything it doesn't recognise
and keeps the originals as `*.orig`. Draft reports for the projects involved are in
[`docs/upstream-issues.md`](docs/upstream-issues.md).

## Troubleshooting

- **Logs:** inside the wrapper at
  `Contents/SharedSupport/prefix/drive_c/users/Sikarugir/AppData/Roaming/ShieldBattery/logs/`:
  `app.0.log` for the client, `game.0.log` for the game.
- **Replays don't show up:** put them in `~/Games/StarCraft/Maps/Replays`. The wrapper keeps
  the Windows Documents folder inside itself on purpose: macOS blocks Finder-launched Wine apps
  from `~/Documents`, which empties ShieldBattery's replay list. So **deleting the
  wrapper also deletes your replays and settings.**
- **Don't switch the renderer to D3DMetal.** It turns the ShieldBattery window black, and the
  `--disable-gpu` flags don't fix that. The default DXMT handles both the app and the game, HD
  included.
- **A game occasionally exits with code `0x80000101`** and no crash dump. It happened a
  handful of times, and trying again worked. Cause unknown. To capture a Wine trace, set
  `Debug Mode` to `1` and `WINEDEBUG` to `-plugplay,+seh,+loaddll` in the wrapper's
  `Contents/Info.plist`. The trace is written to `Contents/SharedSupport/Logs/LastRunWine.log`
  (about 30 MB per game, and it slows the game down).
- **Running Windows programs in the wrapper:** a plain `wine` command doesn't work here. Use
  `Contents/MacOS/wineskinlauncher /path/to/file.exe` (`wrun` in `scripts/common.sh`). Arguments
  are dropped when Wine is already running, so put commands with arguments in a `.bat` file.
- **Rosetta:** Wine runs through Rosetta 2. Apple keeps it fully available through macOS 27 and
  plans to limit it afterwards, so this setup may need an Apple Silicon-native Wine eventually.

## Repository layout

| Path | Purpose |
|---|---|
| `scripts/1-build-wrapper.sh` … `4-set-hd-identity.sh` | Setup steps |
| `scripts/common.sh` | Wrapper paths and helpers (`wrun`, `wkill`) |
| `scripts/patch_shieldbattery_wine.py` | The two DLL patches |
| `tools/cookie_check.py` | Checks a `cookie.bin` against a MachineGuid and volume serial |
| `tools/hive_guid.py` | Reads the MachineGuid from an offline Windows registry file |
| `tools/winsock-tests/` | Small Windows test programs; build with `brew install mingw-w64`, then `x86_64-w64-mingw32-gcc x.c -lws2_32` |
| `docs/upstream-issues.md` | Bug write-ups for ShieldBattery and rally-point2 / noq-udp |
