# VPN Direct Core remediation execution plan

This branch follows the consolidated exhaustive remediation prompt. The plan is intentionally explicit: known work is not hidden behind “etc.” or “remaining items”.

## Pass 0 — baseline and traceability

- Maintain `REMEDIATION_REQUIREMENTS.json` and `RELEASE_BLOCKER_LEDGER.md`.
- Re-audit current `main`/branch after every substantial merge from Cursor.
- Every code-completable requirement must end `VERIFIED`; only real external dependencies may be `EXTERNAL_BLOCKED`.

## Pass 1 — graph architecture

- Remove silent endpoint drops.
- Separate display grouping from connection topology.
- Introduce stable internal graph identity independent of display names.
- Resolve detours/groups/chains in multiple passes; reject missing refs/cycles.
- Preserve semantic roots in Global Auto.
- Stop coercing multi-node groups to urltest solely because they contain >1 node.
- Add structured graph diagnostics/rejections.
- Add first-class top-level Core `endpoints[]` support alongside `outbounds[]`.

## Pass 2 — WireGuard / AmneziaWG

- Verify exact pinned `v1.14.0-lx.35` endpoint schema and selector/route resolution semantics.
- Replace legacy WG outbound production path with endpoint production path.
- Preserve interface addresses, DNS, MTU, ListenPort, every peer, AllowedIPs, PSK, keepalive and endpoint host/port.
- Preserve all pinned-Core AWG fields; do not flatten advanced AWG options.
- Derive AWG version only from authoritative source/version semantics; do not guess feature boundaries.
- Remove BattleParse/test-only WG rewriting and run exact production graph through Core validation.
- Golden fixtures: WG multi-peer, AWG2, AWG3.0, AWG3.1+.

## Pass 3 — final config lifecycle / tunnel fail-closed

- Canonical order: generate → migrate → validate exact final JSON → return/store exact validated JSON.
- Remove best-effort `try? migrate ?? raw` startup paths.
- Validate final graph referential integrity after migration.
- Normalize/redact Core errors and prevent secret-bearing config from logs.

## Pass 4 — typed normalized shared models

- Structured JSON value representation instead of connection-critical `[String:String]` flattening.
- Typed TLS, transport, multiplex, QUIC, Dial, DNS, routing, MTU, WG/AWG, Mieru and MASQUE options.
- Preserve field presence semantics: explicit / absent-by-source / authoritative-default.
- Separate semantic equality/fingerprint from provenance/source text.
- Eliminate legacy prebuilt `NormalizedNode.outbound` writers and early-return bypass.

## Pass 5 — protocol-by-protocol exhaustive field coverage

- VLESS TCP/WS/gRPC/HTTPUpgrade + TLS/Reality/Vision.
- VLESS XHTTP exact pinned schema.
- VLESS encryption/PQ exact pinned schema and capability fail-closed.
- VMess current fields including global padding/authenticated length/network/packet encoding/multiplex/transports.
- Trojan network/TLS/multiplex/transports.
- Shadowsocks + Shadowsocks 2022 methods/plugins/network/UOT/multiplex.
- Hysteria v1 exact schema.
- Hysteria2 server_ports/port hopping/hop intervals/Slamander/Gecko/QUIC/current extras.
- TUIC v5 UDP modes/UOS/zero-RTT/heartbeat/network/QUIC.
- AnyTLS current client idle-session fields.
- ShadowTLS v1/v2/v3 client fields.
- NaiveProxy current full outbound schema.
- WireGuard.
- AWG2 / AWG3.0 / AWG3.1+.
- MASQUE CONNECT-IP standard h3/h2.
- WARP via MASQUE Cloudflare profile h3/h2, imported identity, pinning, IPs and keys.
- Mieru TCP, UDP, Low Entropy modes, multi-port and exact donor configuration.
- SSH current fields without invented `root` default.
- SOCKS4 / SOCKS4a / SOCKS5 including network/UOT where supported.
- HTTP / HTTPS proxy fields including path/headers/TLS where supported.
- Explicit recognition for out-of-scope CONNECT-UDP/Tailscale/OpenVPN/OpenConnect instead of misparse.

## Pass 6 — panel / producer exhaustive coverage

- Remnawave response types, UA rules, routing and alternate path behaviour.
- 3x-ui object/array JSON, flat/nested shapes, mux/final-mask/routing settings.
- x-ui.
- tx-ui.
- Marzban.
- Marzneshin.
- PasarGuard.
- Hiddify Manager + Hiddify App URL/config semantics including fragment/mux.
- Libertea failover/group topology.
- s-ui native sing-box topology/provider-backed groups.
- wg-easy multi-peer/WG configuration.
- Amnezia self-host/AWG configuration.

## Pass 7 — formats and topology

- Direct share URI, plain URI list, base64 URI list.
- Xray JSON top-level object and array.
- Native sing-box JSON.
- Clash, Mihomo and Stash YAML dialects.
- WG conf, AWG conf, Mieru JSON and panel-specific payloads.
- Metadata/comment prefix extraction before structural detection.
- Proxy groups/providers, select/url-test/fallback/load-balance/relay/chain, nested references and cycle validation.
- Structural content detection; base64 decoded content must be re-detected even with no share-link scheme.

## Pass 8 — subscription HTTP / privacy / persistence

- No HWID/device fingerprint on first request to an arbitrary unknown subscription host.
- Cross-origin redirect policy based on scheme + host + effective port; reject HTTPS→HTTP downgrade by default.
- Strip Authorization, Proxy-Authorization, Cookie and all identity headers cross-origin.
- Streaming hard body cap, not post-download `data.count` only.
- Typed bounded HTTP 4xx/451 errors preserving safe body/headers for panel classification.
- Durable HWID persistence; no delete-before-add Keychain rotation failure.

## Pass 9 — reproducible Core / Libbox

- Exact pinned base proof before overlays.
- Manifest/verification for all mandatory overlays: XHTTP, AWG, MASQUE, Mieru, encryption/PQ and capability glue.
- No `go get` repair during release build.
- One source of truth for dependency pins.
- Enforce Go/gomobile policy; remove unconditional `gomobile init || true`.
- Require build profile tag file; no silent reduced tag fallback.
- Isolate stale root Libbox before build; only consume artifact produced by this invocation.
- Verify exact requested device/simulator/platform slices and architectures.
- Compute/stamp provenance after prepare: resolved base SHA, prepared tree/overlay hash, go.mod/go.sum, tags and toolchain.

## Pass 10 — tests and evidence

- Source-derived fixtures with provenance.
- Field-by-field exact normalized/final-JSON assertions.
- Cross-format semantic equivalence.
- Fuzz/property tests for parser/detector/graph where practical.
- Actual built capability JSON; no hardcoded battle capabilities.
- Production graph used by battle/test path; no test-only schema fixes.

## Pass 11 — clean regression/build gates

- Parser/fixture/field coverage tests.
- `LibboxCheckConfig` on exact final production JSON.
- Rebuild `Libbox.xcframework` from exact pin/overlay profile.
- Build iOS host + Packet Tunnel Extension.

## Pass 12 — physical iPhone when available

- Install/launch with `devicectl` when paired/signing environment exists.
- Start PacketTunnel and capture safe logs.
- Missing physical device/signing may be `EXTERNAL_BLOCKED`; code/test work may not.

## Pass 13 — final HEAD re-audit

- Re-read every changed runtime/build/test file.
- Re-run requirement coverage, tests, Core build and iOS build.
- Add newly discovered code-completable problems to the ledger and continue until none remain open.
