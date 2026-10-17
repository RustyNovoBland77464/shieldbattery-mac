# Upstream bugs found

Drafts, not filed yet.

## ShieldBattery: `sb_init_64.dll` has no DllMain return value

`game/dist/sb_init_64.dll` (from `tools/sb_init_64.dll`, last changed in commit 5d89ef302) has
`AddressOfEntryPoint` RVA 0x2fd7, which is a lone `ret` (0xC3). The BOOL that DllMain returns
is therefore whatever RAX holds. Under Wine it's 0, so `LoadLibrary` fails with 1114 and the
game hangs at "Launching game…" (`Panic at src\lib.rs:304 Unable to load sb_init.dll`).
Setting the entry point to 0 fixes it. Suggested fix: build with a DllMain that returns
TRUE, or with `/NOENTRY`. (The 32-bit `sb_init.dll` has a different entry point and wasn't checked.)

## rally-point2 / noq-udp 1.3.0: IPv4 socket options on a dual-stack socket under Wine on macOS

`noq-udp/src/windows.rs` `UdpSocketState::new` sets `IP_DONTFRAGMENT` and `IP_PKTINFO` on
the dual-stack IPv6 socket built by `rally-point2/client/src/dial.rs`
`ClientEndpoint::bind_on_port`. Measured under Wine 11 on macOS 26 on an AF_INET6 socket with
V6ONLY=0:

| option | result |
|---|---|
| IP_DONTFRAGMENT | 10022 (WSAEINVAL) |
| IP_PKTINFO | 10022 |
| IP_RECVECN | 10042 |
| IPV6_DONTFRAG / IPV6_PKTINFO | OK |
| IPV6_RECVECN | 10042 |

`is_unsupported_error` only accepts 10042 and 10045, so the endpoint fails with `binding the
client UDP socket failed … (os error 10022)`. Suggested fix: treat WSAEINVAL as unsupported for
IPv4-level options on an IPv6 socket, or skip them when `IS_WINE`.
