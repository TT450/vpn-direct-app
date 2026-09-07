# Battle Coverage Matrix

Living matrix. Do **not** mark live/device columns without evidence files.  
Updated: **2026-09-07** (first honest public battle pass: fetch+parse validate-only; live connect not run).

Status cells: `scaffold` | `planned` | `pass` | `fail` | `n/a` | `oos`

| Variant | Public sources | Reference lab | Parser fixture | Core validation | Live public | Own interop | Device |
| --- | --- | --- | --- | --- | --- | --- | --- |
| vless-tcp | pass | scaffold | pass | planned | planned | planned | planned |
| vless-tls | pass | scaffold | pass | planned | planned | planned | planned |
| vless-reality | pass | scaffold | pass | planned | planned | planned | planned |
| vless-vision | pass | scaffold | pass | planned | planned | planned | planned |
| vless-ws | pass | scaffold | pass | planned | planned | planned | planned |
| vless-grpc | pass | scaffold | pass | planned | planned | planned | planned |
| vless-httpupgrade | pass | scaffold | pass | planned | planned | planned | planned |
| vless-xhttp | pass | scaffold | pass | planned | n/a | planned | planned |
| vless-xhttp-reality | pass | scaffold | pass | planned | n/a | planned | planned |
| vless-encryption-pq | pass | scaffold | pass | planned | n/a | planned | planned |
| vmess | pass | scaffold | pass | planned | planned | planned | planned |
| trojan | pass | scaffold | pass | planned | planned | planned | planned |
| shadowsocks | pass | scaffold | pass | planned | planned | planned | planned |
| shadowsocks-2022 | pass | scaffold | pass | planned | planned | planned | planned |
| hysteria | planned | scaffold | pass | planned | planned | planned | planned |
| hysteria2 | pass | scaffold | pass | planned | planned | planned | planned |
| hy2-salamander | pass | scaffold | pass | planned | planned | planned | planned |
| hy2-gecko | planned | scaffold | pass | planned | n/a | planned | planned |
| tuic-v5 | pass | scaffold | pass | planned | planned | planned | planned |
| anytls | pass | scaffold | pass | planned | planned | planned | planned |
| shadowtls | n/a | scaffold | pass | planned | n/a | planned | planned |
| naive | n/a | scaffold | pass | planned | n/a | planned | planned |
| wireguard | pass | scaffold | pass | planned | planned | planned | planned |
| amneziawg-2 | n/a | scaffold | pass | planned | n/a | planned | planned |
| amneziawg-3.0 | n/a | scaffold | pass | planned | n/a | planned | planned |
| amneziawg-3.1 | n/a | scaffold | pass | planned | n/a | planned | planned |
| masque-connect-ip | n/a | scaffold | pass | planned | n/a | planned | planned |
| warp-masque | pass | scaffold | pass | planned | external | planned | planned |
| mieru-tcp | n/a | scaffold | pass | planned | n/a | planned | planned |
| mieru-udp | n/a | scaffold | pass | planned | n/a | planned | planned |
| mieru-le-* | n/a | scaffold | pass | planned | n/a | planned | planned |
| socks | n/a | scaffold | pass | planned | n/a | planned | planned |
| http/https-proxy | n/a | scaffold | pass | planned | n/a | planned | planned |
| ssh | n/a | scaffold | pass | planned | n/a | planned | planned |
| connect-udp / tailscale / openvpn / ssr | oos | oos | oos | oos | oos | oos | oos |

Parser fixture `pass` refers to in-tree regression/public-derived fixtures + Swift XCTests — not live public success.

Public sources `pass` = catalog fetch OK + BattleParse exit OK on 2026-09-07 validate-only run (`--limit-per-source 40`). Does **not** imply live connect or remote server liveness. See [`LIVE_PASS_REPORT.md`](LIVE_PASS_REPORT.md).
