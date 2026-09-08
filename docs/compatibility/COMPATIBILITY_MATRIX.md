# Compatibility matrix (living)

Format columns: URI | Xray JSON | sing-box | Clash | panel fixtures | interop | device

Statuses: `yes` | `partial` | `no` | `planned` | `out_of_scope`

| Protocol / Panel | URI | Xray JSON | sing-box | Clash | fixtures | interop | device |
| --- | --- | --- | --- | --- | --- | --- | --- |
| VLESS | yes | partial | yes | partial | partial | planned | planned |
| VMess | yes | partial | yes | partial | partial | planned | planned |
| Trojan | yes | partial | yes | partial | partial | planned | planned |
| Shadowsocks | yes | partial | yes | partial | partial | planned | planned |
| Hysteria/HY2 | yes | partial | yes | partial | partial | planned | planned |
| TUIC | yes | no | yes | no | partial | planned | planned |
| AnyTLS | yes | no | yes | no | partial | planned | planned |
| ShadowTLS | yes | no | yes | no | partial | planned | planned |
| Naive | yes | no | yes | no | partial | planned | planned |
| WireGuard | yes | no | yes | partial | partial | planned | planned |
| AmneziaWG | yes | no | yes | no | partial | planned | planned |
| MASQUE CONNECT-IP / WARP | partial | no | yes | no | partial | planned | planned |
| MASQUE CONNECT-UDP | JSON | no | yes | no | partial | planned | planned |
| Mieru | json | no | yes | no | yes | planned | planned |
| OpenVPN / OpenConnect | file | no | yes | no | partial | planned | planned |
| Tailscale | JSON | no | yes | no | partial | planned | planned |
| Remnawave | — | partial | planned | planned | partial | planned | planned |
| 3x-ui | partial | partial | no | partial | partial | planned | planned |
| Marzban | planned | planned | planned | planned | stub | planned | planned |
| Hiddify | planned | planned | planned | planned | stub | planned | planned |
| s-ui | — | — | planned | — | stub | planned | planned |

CONNECT-UDP and Tailscale need a Libbox rebuild (`masqueConnectUDP` / `with_tailscale`) before device runtime.

Authoritative protocol Core status remains [`docs/core/PROTOCOL_MATRIX.md`](../core/PROTOCOL_MATRIX.md).
