"""Check which (MachineGuid, volume serial) authenticates SC:R's entry in a Battle.net cookie.bin."""
import base64, hashlib, hmac, sys

def fields(buf):
    i = 0
    while i < len(buf):
        def varint():
            nonlocal i
            v = s = 0
            while True:
                b = buf[i]; i += 1
                v |= (b & 0x7F) << s; s += 7
                if b < 0x80: return v
        key = varint(); f, wt = key >> 3, key & 7
        if wt == 0: yield f, varint()
        elif wt == 2:
            n = varint(); yield f, buf[i:i + n]; i += n
        elif wt == 1: yield f, buf[i:i + 8]; i += 8
        elif wt == 5: yield f, buf[i:i + 4]; i += 4
        else: raise ValueError(wt)

cookie = open(sys.argv[1], "rb").read()
guid = sys.argv[2]
serials = sys.argv[3:]
games = {}
for f, v in fields(cookie):
    if f == 5:
        d = dict(fields(v)); games[d.get(4)] = d
print("games in cookie:", sorted(games))
payload = base64.b64decode(games[21297][2])
assert payload[:4] == bytes.fromhex("EFC22400"), payload[:4].hex()
salt, mac, ct = payload[4:14], payload[14:34], payload[34:]
for serial in serials:
    hwid = base64.b64encode(hashlib.sha1(f"{guid}{serial}".encode()).digest()).decode()
    keys = hashlib.pbkdf2_hmac("sha512", hwid.encode(), salt, 8192, 80)
    ok = hmac.new(keys[32:64], ct, hashlib.sha512).digest()[:20] == mac
    print(f"serial {serial:>12}: {'MATCH' if ok else 'no'}")
