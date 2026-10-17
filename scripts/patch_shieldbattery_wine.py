"""Patch ShieldBattery's game DLLs so they work under Wine on macOS.

Re-run after every ShieldBattery update (the updater restores the originals).
Originals are kept next to each DLL as `<name>.orig` on first patch.

1. sb_init_64.dll: its PE entry point is a bare `ret`, so DllMain's BOOL result
   is whatever RAX held. Windows' loader leaves it non-zero; Wine's leaves 0,
   so LoadLibrary fails with ERROR_DLL_INIT_FAILED (1114) and the game hangs at
   "Launching game". Fix: entry point 0 = no DllMain.

2. shieldbattery_64.dll (multiplayer only): noq-udp sets IP_DONTFRAGMENT and
   IP_PKTINFO on a dual-stack IPv6 UDP socket. macOS rejects IPv4-level options
   on IPv6 sockets with EINVAL, which Wine surfaces as WSAEINVAL (10022). noq-udp
   only tolerates WSAENOPROTOOPT (10042) / WSAEOPNOTSUPP (10045), so the relay
   socket fails to build ("binding the client UDP socket failed ... os error
   10022"). Fix: at those two sites, accept 10022 instead of 10045, so noq-udp
   treats the options as unsupported (assumes fragmentation, no IPv4 pktinfo).
"""
import os
import shutil
import struct
import sys

DEFAULT_DIST = os.path.expanduser(
    "~/Applications/Sikarugir/ShieldBattery.app/Contents/SharedSupport/prefix/drive_c/users/"
    "Sikarugir/AppData/Local/Programs/shieldbattery-app/resources/game/dist"
)

WSAEOPNOTSUPP_CMP = bytes.fromhex("3d3d270000")  # cmp eax, 0x273d
WSAEINVAL_CMP = bytes.fromhex("3d26270000")  # cmp eax, 0x2726
NOPROTOOPT_CMP = bytes.fromhex("3d3a270000")  # cmp eax, 0x273a


def backup(path):
    bak = path + ".orig"
    if not os.path.exists(bak):
        shutil.copy2(path, bak)


def patch_sb_init(path):
    data = bytearray(open(path, "rb").read())
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    assert data[pe:pe + 4] == b"PE\0\0", path
    ep_off = pe + 24 + 16
    ep = struct.unpack_from("<I", data, ep_off)[0]
    if ep == 0:
        return "already patched"
    nsec = struct.unpack_from("<H", data, pe + 6)[0]
    opt_size = struct.unpack_from("<H", data, pe + 20)[0]
    sec = pe + 24 + opt_size
    op = None
    for i in range(nsec):
        vsize, va, raw_size, raw_ptr = struct.unpack_from("<IIII", data, sec + i * 40 + 8)
        if va <= ep < va + max(vsize, raw_size):
            op = data[raw_ptr + ep - va]
            break
    if op != 0xC3:
        return f"SKIPPED: entry point is not a bare ret (0x{op:02x}) - DLL changed, needs a look"
    backup(path)
    struct.pack_into("<I", data, ep_off, 0)
    open(path, "wb").write(data)
    return f"entry 0x{ep:x} (ret) -> 0"


def patch_noq_udp(path):
    data = bytearray(open(path, "rb").read())
    results = []
    changed = False
    # xor edx, edx (level IPPROTO_IP = 0); mov r8d, <optname>
    for name, opt in (("IP_DONTFRAGMENT", 0x0E), ("IP_PKTINFO", 0x13)):
        anchor = b"\x31\xd2\x41\xb8" + struct.pack("<I", opt)
        sites = []
        start = 0
        while (i := data.find(anchor, start)) != -1:
            start = i + 1
            window = data[i:i + 0x80]
            j = window.find(NOPROTOOPT_CMP)
            if j == -1 or window[j + 5] != 0x74:  # cmp 0x273a; je rel8
                continue
            k = j + 7
            if window[k:k + 5] in (WSAEOPNOTSUPP_CMP, WSAEINVAL_CMP):
                sites.append(i + k)
        if len(sites) != 1:
            results.append(f"{name}: SKIPPED, found {len(sites)} candidate sites (expected 1) - DLL changed, needs a look")
            continue
        off = sites[0]
        if data[off:off + 5] == WSAEINVAL_CMP:
            results.append(f"{name}: already patched")
        else:
            data[off:off + 5] = WSAEINVAL_CMP
            changed = True
            results.append(f"{name}: accept WSAEINVAL at file offset 0x{off:x}")
    if changed:
        backup(path)
        open(path, "wb").write(data)
    return "; ".join(results)


def main():
    dist = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DIST
    print("sb_init_64.dll:", patch_sb_init(os.path.join(dist, "sb_init_64.dll")))
    print("shieldbattery_64.dll:", patch_noq_udp(os.path.join(dist, "shieldbattery_64.dll")))


if __name__ == "__main__":
    main()
