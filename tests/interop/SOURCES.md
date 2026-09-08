# Interop / harvest source index

Two layers — do not conflate:

| Layer | Role | Examples |
| --- | --- | --- |
| **PUBLIC_DISCOVERY** | Parser fuzz, URI diversity, Clash/sing-box stress | GitHub free feeds below |
| **TRUSTED_INTEROP** | `Interop: planned → tested` evidence | `interop/protocols/<family>/` battle-keys (optional public candidate after live DNS/HTTP/UDP proof) |

Machine catalog: [`tests/battle/public-sources.json`](../battle/public-sources.json)  
Fetch / parse: `scripts/battle/fetch_public_sources.py`, `scripts/battle/parse_cached_sources.py`, `scripts/battle/run_battle_tests.sh`

## Matrix × public harvest (verified 2026-09-08)

| Protocol | Auto-harvest | Primary feeds | Notes |
| --- | --- | --- | --- |
| VLESS / VMess / Trojan / SS | YES | 0xRadikal, Au1rxx, anonymouskeys, snakem982, vlessnode | |
| **VLESS XHTTP** | YES | anonymouskeys `output/transport/xhttp.txt` | Prefer transport slice over guessing |
| **SS2022** | YES | kasesm `ss_raw.txt` (+ Au1rxx Clash) | Look for `2022-blake3-*` |
| Hysteria2 | YES | 0xRadikal, Au1rxx, share-daily, hysteria2.github.io | Date-stamped URLs rotate |
| TUIC | YES | 0xRadikal | Sparse |
| AnyTLS | YES | 0xRadikal anytls.txt, snakem982 Clash (volatile count) | xyfqzy Clash often empty on a given day |
| WireGuard | YES | morpheusadam, Au1rxx sing-box, Delta-Kronecker WARP txt | |
| AmneziaWG | YES (parser) | Delta-Kronecker `AmneziaWG.zip` | Confirm AWG 2 vs 3.x fields before `tested` |
| MASQUE CONNECT-IP / WARP | YES (managed) | Cloudflare WARP + sing-box-lx profile | Own MASQUE server not required |
| Mieru | ⚠️ | snakem982 claims; **0 mieru on 2026-09-08 probe** | Keep hunting; lab still valid fallback |
| ShadowTLS / Naive / ML-KEM | ⚠️ | Not confirmed as live URI yet | Fixtures OK; no fake battle-keys |
| SSR | YES | 0xRadikal shadowsocksr.txt | Needs Libbox rebuild (`with_shadowsocksr`) |
| SOCKS / HTTP / SSH | ⚠️ | Prefer lab | Avoid random public SSH |
| CONNECT-UDP / Tailscale / OpenVPN | NO | — | Core 1.x `out_of_scope` |

## Policy

- GitHub URI ≠ interop `tested`.
- Dead/empty volatile feeds warn only in CI.
- Prefer ≥2 independent feeds per protocol before trusting harvest for qualification candidates.
- Still no silent own-server requirement for protocols that already have public/managed sources.
