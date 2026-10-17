"""Find MachineGuid value(s) in a Windows SOFTWARE registry hive (regf) by scanning vk cells."""
import re, struct, sys

data = open(sys.argv[1], "rb").read()
assert data[:4] == b"regf"
BASE = 0x1000
for m in re.finditer(rb"vk\x0b\x00", data):  # vk record with 11-char name
    o = m.start()
    name_len, size, off, typ, flags = struct.unpack_from("<HIIIH", data, o + 2)
    name = data[o + 20:o + 20 + name_len]
    if name != b"MachineGuid" or typ != 1:  # REG_SZ
        continue
    size &= 0x7FFFFFFF
    val = data[BASE + off + 4:BASE + off + 4 + size].decode("utf-16-le").rstrip("\0")
    print(val)
