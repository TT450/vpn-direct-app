# Remediation Execution Plan

Source: `master_prompt_union` · Generated registry: `2026-09-07` · Requirements: **217**

Companion: [`REMEDIATION_REQUIREMENTS.json`](REMEDIATION_REQUIREMENTS.json), [`RELEASE_BLOCKER_LEDGER.md`](RELEASE_BLOCKER_LEDGER.md).

Traceability rule: every `REQ-*` id below MUST appear in this plan. Coverage gate: `python3 scripts/check_remediation_plan_coverage.py` → `UNPLANNED=0`.

## Pass 0 — Full requirement compilation / traceability / baseline

_No requirements assigned to this pass._

## Pass 1 — Core graph architecture + stable identity + endpoints/outbounds

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-P005` | P0 | IMPLEMENTED_UNVERIFIED | SILENT DROP В SingBoxGraphBuilder |
| `REQ-P023` | P1 | OPEN | SUBSCRIPTION DOWNLOAD SIZE LIMIT |
| `REQ-P048` | P1 | OPEN | TRANSPORT OPTIONS НЕЛЬЗЯ СВОДИТЬ К path/host/service_name |
| `REQ-P064` | P1 | OPEN | CLASH NESTED GROUPS / GRAPH VALIDATION |
| `REQ-P069` | P1 | OPEN | TYPE COERCION / STRINGIFICATION |
| `REQ-P071` | P1 | OPEN | NO SILENT SEMANTIC DEGRADATION — GLOBAL INVARIANT |
| `REQ-P072` | P1 | OPEN | НЕ ОСТАНАВЛИВАТЬСЯ НА ИЗВЕСТНОМ СПИСКЕ |
| `REQ-P073` | P0 | OPEN | SingBoxGraphBuilder ВСЁ ЕЩЁ SILENTLY DROPS ENDPOINTS |
| `REQ-P074` | P0 | OPEN | Clash/Xray FIX ПЕРЕШЁЛ ИЗ SILENT DROP В ALL-OR-NOTHING |
| `REQ-P075` | P1 | OPEN | NormalizedLocationStrategy СЛИШКОМ БЕДНЫЙ |
| `REQ-P076` | P0 | OPEN | GraphBuilder ПРИНУДИТЕЛЬНО ДЕЛАЕТ ЛЮБУЮ MULTI-NODE LOCATION URLTEST |
| `REQ-P077` | P0 | OPEN | GLOBAL AUTO ОБХОДИТ LOCATION/GROUP SEMANTICS |
| `REQ-P078` | P0 | OPEN | DETOUR FORWARD REFERENCE СЛОМАН ДЛЯ SINGLE LOCATION |
| `REQ-P079` | P0 | OPEN | MISSING DETOUR REFERENCE SILENTLY IGNORED |
| `REQ-P080` | P0 | OPEN | NODE NAME НЕ ЯВЛЯЕТСЯ НАДЁЖНЫМ REFERENCE ID |
| `REQ-P082` | P1 | OPEN | GLOBAL `prefer_ipv4` МОЖЕТ ЛОМАТЬ IPv6/DUAL-STACK |
| `REQ-P083` | P1 | OPEN | TUN MTU=9000 HARDCODED |
| `REQ-P084` | P1 | OPEN | PRIVATE NETWORKS ВСЕГДА ИДУТ DIRECT |
| `REQ-P087` | P1 | OPEN | Xray BALANCER В ТЕКУЩЕМ HEAD ВСЁ ЕЩЁ СВЕДЁН К hasBalancers |
| `REQ-P118` | P0 | OPEN | GraphBuilder HAS NO ENDPOINT COLLECTION FOR MODERN ENDPOINT TYPES |
| `REQ-P121` | P1 | OPEN | SHARE NODE ALWAYS MARKED `.country` |
| `REQ-P122` | P1 | OPEN | COUNTRY/UI GROUPING AND CONNECTION TOPOLOGY ARE MIXED |
| `REQ-P131` | P1 | OPEN | BOOLEAN PARSING IS AD-HOC (`"1"` ONLY) |
| `REQ-P132` | P1 | OPEN | UNKNOWN TRANSPORT CAN STILL DISAPPEAR INTO “NO TRANSPORT” |
| `REQ-SHARED-DNS` | P0 | OPEN | Shared DNS semantics (not hardcoded) |
| `REQ-SHARED-ROUTING` | P0 | OPEN | Shared routing / bypass / panel routing |

IDs: `REQ-P005` `REQ-P023` `REQ-P048` `REQ-P064` `REQ-P069` `REQ-P071` `REQ-P072` `REQ-P073` `REQ-P074` `REQ-P075` `REQ-P076` `REQ-P077` `REQ-P078` `REQ-P079` `REQ-P080` `REQ-P082` `REQ-P083` `REQ-P084` `REQ-P087` `REQ-P118` `REQ-P121` `REQ-P122` `REQ-P131` `REQ-P132` `REQ-SHARED-DNS` `REQ-SHARED-ROUTING`

## Pass 2 — WG/AWG complete production endpoint path

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-P001` | P0 | IMPLEMENTED_UNVERIFIED | WIREGUARD / AMNEZIAWG СЕЙЧАС СТРОЯТСЯ НЕПРАВИЛЬНО |
| `REQ-P002` | P0 | IMPLEMENTED_UNVERIFIED | WIREGUARD / AWG NORMALIZATION ТЕРЯЕТ ДАННЫЕ |
| `REQ-P003` | P0 | IMPLEMENTED_UNVERIFIED | AWG VERSION DETECTION СЕЙЧАС СЛОМАН |
| `REQ-P004` | P0 | IMPLEMENTED_UNVERIFIED | BATTLE TEST СЕЙЧАС НЕ ДОЛЖЕН МАСКИРОВАТЬ PRODUCTION BUGS |
| `REQ-P006` | P0 | IMPLEMENTED_UNVERIFIED | XRAY / REMNAWAVE PARTIAL FAILURE |
| `REQ-P007` | P0 | IMPLEMENTED_UNVERIFIED | XRAY BALANCER НОРМАЛИЗУЕТСЯ НЕПРАВИЛЬНО |
| `REQ-P008` | P0 | IMPLEMENTED_UNVERIFIED | НЕПРАВИЛЬНЫЙ DEDUPE |
| `REQ-P134` | P0 | OPEN | AWG VERSION INFERENCE MUST NOT BE LOCKED FROM GUESSED FIELD BOUNDARIES |

IDs: `REQ-P001` `REQ-P002` `REQ-P003` `REQ-P004` `REQ-P006` `REQ-P007` `REQ-P008` `REQ-P134`

## Pass 3 — Final config lifecycle / migrate / validate / extension fail-closed

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-P027` | P1 | OPEN | rawExtensions СЕЙЧАС LOSSY |
| `REQ-P085` | P0 | IMPLEMENTED_UNVERIFIED | CONFIG VALIDATION И MIGRATION СТОЯТ В НЕПРАВИЛЬНОМ ПОРЯДКЕ |
| `REQ-P119` | P0 | OPEN | MIGRATOR CAN CHANGE TAGS/SCHEMA AFTER GRAPH REFERENCES WERE BUILT |
| `REQ-P123` | P0 | OPEN | CORE ERROR AFTER LibboxCheckConfig IS THROWN AS RAW NSError |
| `REQ-P124` | P0 | OPEN | NO FINAL SECRET-SAFE CONFIG DIAGNOSTIC BOUNDARY |

IDs: `REQ-P027` `REQ-P085` `REQ-P119` `REQ-P123` `REQ-P124`

## Pass 4 — Typed normalized shared models

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-P026` | P1 | OPEN | LEGACY NormalizedNode.outbound EARLY RETURN |
| `REQ-P053` | P1 | OPEN | VMESS ADVANCED OUTBOUND OPTIONS |
| `REQ-P068` | P1 | OPEN | DEFAULT VALUE DRIFT |
| `REQ-P126` | P1 | OPEN | HYSTERIA BUILDER RE-PARSES `source` AND CAN BYPASS NORMALIZED STATE |
| `REQ-P128` | P1 | OPEN | MIERU CURRENT BUILDER SILENTLY DEFAULTS TRANSPORT TO TCP |
| `REQ-P129` | P1 | OPEN | SSH BUILDER SILENTLY DEFAULTS USER TO `root` |
| `REQ-P136` | P1 | OPEN | NormalizedNode EQUATABLE IGNORES `outbound` |
| `REQ-SHARED-DIAL` | P0 | OPEN | Shared dial / bind / domain strategy |
| `REQ-SHARED-MULTIPLEX` | P0 | OPEN | Shared multiplex / mux options |
| `REQ-SHARED-QUIC` | P0 | OPEN | Shared QUIC / HY2 / TUIC options |
| `REQ-SHARED-TLS` | P0 | OPEN | Shared TLS model (SNI/ALPN/ECH/Reality/utls) |
| `REQ-SHARED-V2RAY-TRANSPORT` | P0 | OPEN | Shared V2Ray transports (ws/grpc/httpupgrade/xhttp/h2) |

IDs: `REQ-P026` `REQ-P053` `REQ-P068` `REQ-P126` `REQ-P128` `REQ-P129` `REQ-P136` `REQ-SHARED-DIAL` `REQ-SHARED-MULTIPLEX` `REQ-SHARED-QUIC` `REQ-SHARED-TLS` `REQ-SHARED-V2RAY-TRANSPORT`

## Pass 5 — Exhaustive protocol-by-protocol implementation

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-P011` | P0 | OPEN | XRAY VLESS UNKNOWN TRANSPORT МОЖЕТ ТИХО СТАТЬ TCP |
| `REQ-P012` | P0 | OPEN | VLESS ENCRYPTION / PQ НЕ ДОЛЖНЫ ТИХО ИСЧЕЗАТЬ |
| `REQ-P015` | P0 | OPEN | PROTOCOL SUPPORT != FORMAT SUPPORT |
| `REQ-P029` | P0 | OPEN | VLESS ПОЛНОСТЬЮ |
| `REQ-P030` | P0 | OPEN | HYSTERIA / HYSTERIA2 |
| `REQ-P031` | P0 | OPEN | MIERU |
| `REQ-P032` | P0 | OPEN | MASQUE / WARP |
| `REQ-P033` | P0 | OPEN | SHADOWTLS CHAINS |
| `REQ-P034` | P0 | OPEN | NAIVEPROXY |
| `REQ-P049` | P0 | OPEN | HYSTERIA2 SERVER_PORTS / PORT HOPPING |
| `REQ-P050` | P0 | OPEN | HYSTERIA2 / QUIC ADVANCED OPTIONS |
| `REQ-P051` | P0 | OPEN | TUIC v5 ПОДДЕРЖАН НЕ ПОЛНОСТЬЮ |
| `REQ-P052` | P0 | OPEN | VLESS MULTIPLEX / MUX |
| `REQ-P054` | P0 | OPEN | SHADOWSOCKS / SS2022 ADVANCED OPTIONS |
| `REQ-P056` | P0 | OPEN | TLS MODEL СЕЙЧАС СЛИШКОМ УЗКИЙ |
| `REQ-P057` | P0 | OPEN | NAIVEPROXY BUILDER СЕЙЧАС НЕДОСТАТОЧЕН |
| `REQ-P089` | P0 | OPEN | Xray PROTOCOL FILTER СЛИШКОМ УЗКИЙ |
| `REQ-P097` | P0 | OPEN | OUT-OF-SCOPE PROTOCOLS ARE NOT RECOGNIZED EXPLICITLY |
| `REQ-P127` | P0 | OPEN | MASQUE BUILDER CURRENTLY CONFLATES GENERIC MASQUE WITH WARP |
| `REQ-P135` | P0 | OPEN | WARP REGISTRATION API IS NOT A BLOCKER FOR EXISTING-IDENTITY IMPORT |
| `REQ-PROTO-ANYTLS` | P0 | OPEN | AnyTLS |
| `REQ-PROTO-AWG2` | P0 | IMPLEMENTED_UNVERIFIED | AmneziaWG 2.x |
| `REQ-PROTO-AWG30` | P0 | IMPLEMENTED_UNVERIFIED | AmneziaWG 3.0 |
| `REQ-PROTO-AWG31` | P0 | IMPLEMENTED_UNVERIFIED | AmneziaWG 3.1+ |
| `REQ-PROTO-HTTP` | P0 | OPEN | HTTP proxy |
| `REQ-PROTO-HTTPS` | P0 | OPEN | HTTPS proxy |
| `REQ-PROTO-HY1` | P0 | OPEN | Hysteria v1 |
| `REQ-PROTO-HY2` | P0 | OPEN | Hysteria2 |
| `REQ-PROTO-HY2-GECKO` | P0 | OPEN | Hysteria2 Gecko |
| `REQ-PROTO-HY2-SAL` | P0 | OPEN | Hysteria2 Salamander |
| `REQ-PROTO-MASQUE-STD` | P0 | OPEN | MASQUE CONNECT-IP standard |
| `REQ-PROTO-MIERU-LE` | P0 | OPEN | Mieru Low Entropy |
| `REQ-PROTO-MIERU-TCP` | P0 | OPEN | Mieru TCP |
| `REQ-PROTO-MIERU-UDP` | P0 | OPEN | Mieru UDP |
| `REQ-PROTO-NAIVE` | P0 | OPEN | NaiveProxy |
| `REQ-PROTO-SHADOWTLS` | P0 | OPEN | ShadowTLS chains |
| `REQ-PROTO-SOCKS4` | P0 | OPEN | SOCKS4/4a |
| `REQ-PROTO-SOCKS5` | P0 | OPEN | SOCKS5 |
| `REQ-PROTO-SS` | P0 | OPEN | Shadowsocks classic |
| `REQ-PROTO-SS2022` | P0 | OPEN | Shadowsocks 2022 |
| `REQ-PROTO-SSH` | P0 | OPEN | SSH outbound |
| `REQ-PROTO-TROJAN` | P0 | OPEN | Trojan outbound field-complete |
| `REQ-PROTO-TUIC` | P0 | OPEN | TUIC v5 |
| `REQ-PROTO-VLESS` | P0 | OPEN | VLESS base transports (TCP/WS/gRPC/HTTPUpgrade/Reality) |
| `REQ-PROTO-VLESS-PQ` | P0 | OPEN | VLESS encryption / post-quantum fields fail-closed |
| `REQ-PROTO-VLESS-XHTTP` | P0 | OPEN | VLESS XHTTP (+ Reality) field-complete |
| `REQ-PROTO-VMESS` | P0 | OPEN | VMess outbound + advanced options |
| `REQ-PROTO-WARP-MASQUE` | P0 | OPEN | WARP via MASQUE (existing identity) |
| `REQ-PROTO-WG` | P0 | IMPLEMENTED_UNVERIFIED | WireGuard endpoints schema |

IDs: `REQ-P011` `REQ-P012` `REQ-P015` `REQ-P029` `REQ-P030` `REQ-P031` `REQ-P032` `REQ-P033` `REQ-P034` `REQ-P049` `REQ-P050` `REQ-P051` `REQ-P052` `REQ-P054` `REQ-P056` `REQ-P057` `REQ-P089` `REQ-P097` `REQ-P127` `REQ-P135` `REQ-PROTO-ANYTLS` `REQ-PROTO-AWG2` `REQ-PROTO-AWG30` `REQ-PROTO-AWG31` `REQ-PROTO-HTTP` `REQ-PROTO-HTTPS` `REQ-PROTO-HY1` `REQ-PROTO-HY2` `REQ-PROTO-HY2-GECKO` `REQ-PROTO-HY2-SAL` `REQ-PROTO-MASQUE-STD` `REQ-PROTO-MIERU-LE` `REQ-PROTO-MIERU-TCP` `REQ-PROTO-MIERU-UDP` `REQ-PROTO-NAIVE` `REQ-PROTO-SHADOWTLS` `REQ-PROTO-SOCKS4` `REQ-PROTO-SOCKS5` `REQ-PROTO-SS` `REQ-PROTO-SS2022` `REQ-PROTO-SSH` `REQ-PROTO-TROJAN` `REQ-PROTO-TUIC` `REQ-PROTO-VLESS` `REQ-PROTO-VLESS-PQ` `REQ-PROTO-VLESS-XHTTP` `REQ-PROTO-VMESS` `REQ-PROTO-WARP-MASQUE` `REQ-PROTO-WG`

## Pass 6 — Exhaustive panel/producer implementation

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-P009` | P0 | OPEN | 3X-UI REAL JSON COMPATIBILITY |
| `REQ-P010` | P1 | OPEN | FIXTURES ДОЛЖНЫ БЫТЬ SOURCE-DERIVED, А НЕ PARSER-DERIVED |
| `REQ-P017` | P1 | OPEN | LIBERTEA FAILOVER SEMANTICS |
| `REQ-P018` | P1 | OPEN | HIDDIFY SMART GROUPS / ROUTING |
| `REQ-P019` | P1 | OPEN | ROUTING HEADER / PANEL ROUTING СЕЙЧАС МОЖЕТ ТОЛЬКО СОХРАНЯТЬСЯ КАК METADATA |
| `REQ-P022` | P1 | OPEN | HTTP ERROR BODY / REMNAWAVE RESPONSE RULES |
| `REQ-P038` | P1 | OPEN | PANEL FINGERPRINTING |
| `REQ-P039` | P1 | OPEN | PANEL MATRIX НЕ ДОЛЖЕН ГОВОРИТЬ “INTEROP TRUE” БЕЗ REAL INTEROP |
| `REQ-P040` | P1 | OPEN | PANEL-SPECIFIC AUDIT |
| `REQ-P047` | P1 | OPEN | 3X-UI SUBSCRIPTION OPTIONS — MUX / FINALMASK / ROUTING |
| `REQ-P055` | P1 | OPEN | HIDDIFY MUX / FRAGMENT / CLIENT OPTIONS |
| `REQ-P058` | P0 | OPEN | REMNAWAVE RESPONSE TYPES — ПОЛНАЯ МАТРИЦА |
| `REQ-P059` | P1 | OPEN | REMNAWAVE ADDITIONAL PATHS МОГУТ БЫТЬ DISABLED |
| `REQ-P060` | P1 | OPEN | REMNAWAVE USER-AGENT × RESPONSE RULE MATRIX |
| `REQ-P061` | P1 | OPEN | HIDDIFY METADATA В BODY НЕ ДОЛЖНА ЛОМАТЬ DETECTOR |
| `REQ-P062` | P1 | OPEN | S-UI NATIVE SING-BOX TOPOLOGY |
| `REQ-P065` | P1 | OPEN | MARZBAN RICH TRANSPORT OUTPUT |
| `REQ-P066` | P1 | OPEN | PANEL COMPATIBILITY ДОЛЖНА БЫТЬ 4-D MATRIX |
| `REQ-P081` | P1 | OPEN | FIXED DNS 1.1.1.1 ЛОМАЕТ PANEL/NATIVE DNS SEMANTICS |
| `REQ-P086` | P1 | OPEN | NATIVE/PANEL ROUTING METADATA НЕ ДОХОДИТ ДО FINAL ROUTE |
| `REQ-P096` | P1 | OPEN | HIDDIFY/PANEL COMMENT PREFIX BEFORE JSON BREAKS PREFIX DETECTION |
| `REQ-P102` | P1 | OPEN | HTTP 4xx/451 BODY LOST BEFORE PANEL ERROR CLASSIFICATION |
| `REQ-P117` | P1 | OPEN | URLTEST DEFAULTS MAY NOT MATCH PANEL SEMANTICS |
| `REQ-P120` | P1 | OPEN | LOCATION KIND/COMMENT STILL REMNAWAVE-CENTRIC |
| `REQ-PANEL-3x-ui` | P0 | OPEN | Panel exhaustive gate: 3x-ui |
| `REQ-PANEL-amnezia` | P0 | OPEN | Panel exhaustive gate: amnezia |
| `REQ-PANEL-hiddify` | P0 | OPEN | Panel exhaustive gate: hiddify |
| `REQ-PANEL-libertea` | P0 | OPEN | Panel exhaustive gate: libertea |
| `REQ-PANEL-marzban` | P0 | OPEN | Panel exhaustive gate: marzban |
| `REQ-PANEL-marzneshin` | P0 | OPEN | Panel exhaustive gate: marzneshin |
| `REQ-PANEL-pasarguard` | P0 | OPEN | Panel exhaustive gate: pasarguard |
| `REQ-PANEL-remnawave` | P0 | OPEN | Panel exhaustive gate: remnawave |
| `REQ-PANEL-s-ui` | P0 | OPEN | Panel exhaustive gate: s-ui |
| `REQ-PANEL-tx-ui` | P0 | OPEN | Panel exhaustive gate: tx-ui |
| `REQ-PANEL-wg-easy` | P0 | OPEN | Panel exhaustive gate: wg-easy |
| `REQ-PANEL-x-ui` | P0 | OPEN | Panel exhaustive gate: x-ui |

IDs: `REQ-P009` `REQ-P010` `REQ-P017` `REQ-P018` `REQ-P019` `REQ-P022` `REQ-P038` `REQ-P039` `REQ-P040` `REQ-P047` `REQ-P055` `REQ-P058` `REQ-P059` `REQ-P060` `REQ-P061` `REQ-P062` `REQ-P065` `REQ-P066` `REQ-P081` `REQ-P086` `REQ-P096` `REQ-P102` `REQ-P117` `REQ-P120` `REQ-PANEL-3x-ui` `REQ-PANEL-amnezia` `REQ-PANEL-hiddify` `REQ-PANEL-libertea` `REQ-PANEL-marzban` `REQ-PANEL-marzneshin` `REQ-PANEL-pasarguard` `REQ-PANEL-remnawave` `REQ-PANEL-s-ui` `REQ-PANEL-tx-ui` `REQ-PANEL-wg-easy` `REQ-PANEL-x-ui`

## Pass 7 — Exhaustive format/topology implementation

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-FMT-awg-conf` | P0 | IMPLEMENTED_UNVERIFIED | AmneziaWG .conf |
| `REQ-FMT-base64` | P0 | OPEN | Base64 URI list |
| `REQ-FMT-clash` | P0 | OPEN | Clash YAML |
| `REQ-FMT-mieru-json` | P0 | OPEN | Mieru JSON |
| `REQ-FMT-mihomo` | P0 | OPEN | Mihomo YAML |
| `REQ-FMT-singbox` | P0 | OPEN | Native sing-box JSON |
| `REQ-FMT-stash` | P0 | OPEN | Stash YAML |
| `REQ-FMT-uri` | P0 | OPEN | Direct share URI |
| `REQ-FMT-uri-list` | P0 | OPEN | Plain URI list subscription |
| `REQ-FMT-wg-conf` | P0 | IMPLEMENTED_UNVERIFIED | WireGuard .conf |
| `REQ-FMT-xray-arr` | P0 | OPEN | Xray JSON array |
| `REQ-FMT-xray-obj` | P0 | OPEN | Xray JSON object |
| `REQ-P013` | P1 | OPEN | XRAY FORMAT SUPPORT НЕ ДОЛЖЕН БЫТЬ ИСКУССТВЕННО УЗКИМ |
| `REQ-P014` | P0 | OPEN | URI LIST PARTIAL IMPORT ТОЖЕ SILENT |
| `REQ-P016` | P1 | OPEN | CLASH / MIHOMO — SYNTAX УЖЕ YAMS, НО SEMANTICS НЕ ПОЛНЫЕ |
| `REQ-P036` | P1 | OPEN | NATIVE SING-BOX JSON |
| `REQ-P037` | P0 | OPEN | CONTENT DETECTOR |
| `REQ-P063` | P1 | OPEN | CLASH / MIHOMO PROXY-PROVIDERS |
| `REQ-P088` | P1 | OPEN | Xray PROFILE PARTIAL LOSS СЕЙЧАС ABORTS WHOLE PROFILE |
| `REQ-P090` | P1 | OPEN | Xray DEDUPE ЕЩЁ НЕ ПОЛНЫЙ |
| `REQ-P092` | P1 | OPEN | Xray `firstString` ТЕРЯЕТ MULTI-VALUE SEMANTICS |
| `REQ-P093` | P0 | OPEN | CONTENT DETECTOR ВСЁ ЕЩЁ HEURISTIC SUBSTRING, НЕ STRUCTURAL JSON |
| `REQ-P094` | P1 | OPEN | XRAY TOP-LEVEL OBJECT НЕ DETECTED |
| `REQ-P095` | P1 | OPEN | BASE64 ENCODED JSON/YAML DETECTION LOGIC BROKEN |

IDs: `REQ-FMT-awg-conf` `REQ-FMT-base64` `REQ-FMT-clash` `REQ-FMT-mieru-json` `REQ-FMT-mihomo` `REQ-FMT-singbox` `REQ-FMT-stash` `REQ-FMT-uri` `REQ-FMT-uri-list` `REQ-FMT-wg-conf` `REQ-FMT-xray-arr` `REQ-FMT-xray-obj` `REQ-P013` `REQ-P014` `REQ-P016` `REQ-P036` `REQ-P037` `REQ-P063` `REQ-P088` `REQ-P090` `REQ-P092` `REQ-P093` `REQ-P094` `REQ-P095`

## Pass 8 — Subscription HTTP/privacy/error semantics

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-HTTP-hwid-policy` | P0 | OPEN | HWID sent only to allowlisted panels |
| `REQ-HTTP-keychain` | P0 | OPEN | Keychain write failures are fail-closed |
| `REQ-HTTP-redirect-origin` | P0 | OPEN | Redirect policy compares origin not host |
| `REQ-HTTP-schemes` | P0 | OPEN | URL scheme / fetch validation |
| `REQ-HTTP-size-limit` | P0 | OPEN | Subscription download size limit before body buffer |
| `REQ-P020` | P0 | OPEN | HTTP SUBSCRIPTION LAYER — НЕ СЛАТЬ HWID ВСЕМ ПОДРЯД |
| `REQ-P021` | P0 | OPEN | REDIRECT HEADER LEAK |
| `REQ-P024` | P1 | OPEN | URL SCHEME / FETCH VALIDATION |
| `REQ-P025` | P0 | OPEN | KEYCHAIN WRITE RESULT |
| `REQ-P035` | P1 | OPEN | SSH / SOCKS / HTTP |
| `REQ-P098` | P0 | OPEN | SubscriptionHTTP HWID PRIVACY FIX ВСЁ ЕЩЁ НЕ РЕШАЕТ FIRST REQUEST LEAK |
| `REQ-P099` | P0 | OPEN | REDIRECT POLICY СРАВНИВАЕТ HOST, А НЕ ORIGIN |
| `REQ-P100` | P0 | OPEN | REDIRECT STRIPPING НЕПОЛНЫЙ |
| `REQ-P101` | P1 | OPEN | SUBSCRIPTION SIZE LIMIT CHECK HAPPENS TOO LATE |
| `REQ-P103` | P0 | OPEN | Keychain FAILURE HANDLING ТОЛЬКО ЛОГИРУЕТ |
| `REQ-P104` | P0 | OPEN | HWID USERDEFAULTS + KEYCHAIN CONSISTENCY IS NOT TRANSACTIONAL |
| `REQ-P130` | P1 | OPEN | XHTTP NUMERIC/STRUCTURED FIELDS EMITTED AS STRINGS |

IDs: `REQ-HTTP-hwid-policy` `REQ-HTTP-keychain` `REQ-HTTP-redirect-origin` `REQ-HTTP-schemes` `REQ-HTTP-size-limit` `REQ-P020` `REQ-P021` `REQ-P024` `REQ-P025` `REQ-P035` `REQ-P098` `REQ-P099` `REQ-P100` `REQ-P101` `REQ-P103` `REQ-P104` `REQ-P130`

## Pass 9 — Core/Libbox reproducible build/provenance

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-BUILD-go-pin` | P0 | OPEN | Go toolchain pin enforced |
| `REQ-BUILD-libbox-slices` | P0 | OPEN | Libbox platform slice completeness |
| `REQ-BUILD-prepare-core` | P0 | OPEN | prepare_core fail-closed apply/verify |
| `REQ-BUILD-provenance` | P0 | OPEN | Core tree provenance / SHA honesty |
| `REQ-BUILD-tag-profile` | P0 | OPEN | Build tag profile exactness |
| `REQ-P043` | P0 | OPEN | LIBBOX BUILD ДОЛЖЕН ПРОВЕРЯТЬ PLATFORM SLICES |
| `REQ-P044` | P0 | OPEN | prepare_core ДОЛЖЕН БЫТЬ НАСТОЯЩИМ FAIL-CLOSED |
| `REQ-P105` | P0 | OPEN | build_libbox RECORDS CORE SHA BEFORE prepare_core |
| `REQ-P106` | P0 | OPEN | build_libbox МОЖЕТ ПОДХВАТИТЬ СТАРЫЙ ROOT Libbox |
| `REQ-P107` | P1 | OPEN | PLATFORM SLICE CHECK ПРОВЕРЯЕТ FAMILY, НЕ EVERY REQUESTED PLATFORM |
| `REQ-P108` | P1 | OPEN | gomobile init ВСЁ ЕЩЁ `\|\| true` |
| `REQ-P109` | P1 | OPEN | GO VERSION PIN ТОЛЬКО ПЕЧАТАЕТСЯ, НЕ ENFORCED |
| `REQ-P110` | P1 | OPEN | BUILD PROFILE TAG FILE MISSING CAN SILENTLY FALL BACK TO INCOMPLETE TAG SET |
| `REQ-P111` | P0 | OPEN | prepare_core APPLY MODE НЕ PROVES HEAD == SING_BOX_REV |
| `REQ-P112` | P0 | OPEN | prepare_core --verify ПРОВЕРЯЕТ ПОЧТИ ТОЛЬКО MIERU |
| `REQ-P113` | P0 | OPEN | prepare_core МОЖЕТ MUTATE go.mod ЧЕРЕЗ `go get` DURING BUILD |
| `REQ-P114` | P1 | OPEN | OVERLAY / DEPENDENCY VERSION HAS TWO SOURCES OF TRUTH |
| `REQ-P115` | P1 | OPEN | FINAL CORE TREE PROVENANCE NOT STRONG ENOUGH |
| `REQ-P137` | P1 | OPEN | `source` IS INCLUDED IN NODE EQUALITY EVEN THOUGH IT SHOULD BE PROVENANCE |

IDs: `REQ-BUILD-go-pin` `REQ-BUILD-libbox-slices` `REQ-BUILD-prepare-core` `REQ-BUILD-provenance` `REQ-BUILD-tag-profile` `REQ-P043` `REQ-P044` `REQ-P105` `REQ-P106` `REQ-P107` `REQ-P108` `REQ-P109` `REQ-P110` `REQ-P111` `REQ-P112` `REQ-P113` `REQ-P114` `REQ-P115` `REQ-P137`

## Pass 10 — Fixtures/provenance/equivalence/fuzz/field coverage

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-P028` | P1 | OPEN | CompatibilityFieldPolicy НЕ ДОЛЖЕН БЫТЬ ТОЛЬКО HEURISTIC |
| `REQ-P041` | P1 | OPEN | TEST COVERAGE — ACTUAL PRODUCTION SWIFT |
| `REQ-P042` | P1 | OPEN | TRUE FUZZ / PROPERTY TESTS |
| `REQ-P067` | P1 | OPEN | CROSS-FORMAT SEMANTIC EQUIVALENCE TESTS |
| `REQ-P070` | P1 | OPEN | KNOWN FIELD НЕ РАВНО SUPPORTED FIELD |
| `REQ-P091` | P1 | OPEN | Xray flattenOutboundFields LOSSY TYPE COERCION ПРЯМО В CURRENT CODE |
| `REQ-P116` | P1 | OPEN | FIXED URLTEST PROBE GOOGLE GSTATIC IS A HIDDEN GLOBAL DEPENDENCY |
| `REQ-P133` | P1 | OPEN | DO NOT ASSUME ENDPOINT TAG WORKS IN SELECTOR/URLTEST UNTIL PINNED CORE PROVES IT |
| `REQ-P138` | P1 | OPEN | LEGACY `outbound` EARLY RETURN BYPASSES FAIL-CLOSED UNKNOWN FIELD CHECK |
| `REQ-P139` | P1 | OPEN | DEFAULTS MUST DISTINGUISH “FIELD ABSENT” FROM “PARSER LOST FIELD” |
| `REQ-P140` | P1 | OPEN | PROTOCOL BUILDERS NEED SCHEMA-DRIVEN REQUIRED/CONDITIONAL FIELD VALIDATION |
| `REQ-TEST-field-coverage` | P1 | OPEN | Protocol field coverage matrix |
| `REQ-TEST-fixture-provenance` | P1 | OPEN | Fixtures are source-derived with provenance |
| `REQ-TEST-fuzz` | P1 | OPEN | True fuzz / property tests |
| `REQ-TEST-production-swift-e2e` | P1 | OPEN | Production Swift path e2e (not BattleParse-only) |

IDs: `REQ-P028` `REQ-P041` `REQ-P042` `REQ-P067` `REQ-P070` `REQ-P091` `REQ-P116` `REQ-P133` `REQ-P138` `REQ-P139` `REQ-P140` `REQ-TEST-field-coverage` `REQ-TEST-fixture-provenance` `REQ-TEST-fuzz` `REQ-TEST-production-swift-e2e`

## Pass 11 — Clean full regression/build gates

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-DEVICE-sfi-build` | P0 | OPEN | SFI / Packet Tunnel compile with embedded Libbox |

IDs: `REQ-DEVICE-sfi-build`

## Pass 12 — Physical iPhone install/launch/tunnel if available

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-DEVICE-iphone-install` | P0 | EXTERNAL_BLOCKED | Physical iPhone install via Xcode/devicectl |
| `REQ-DEVICE-tunnel-start` | P0 | OPEN | Packet Tunnel starts; Libbox setup; TUN up on known-good config |
| `REQ-P045` | P0 | OPEN | IOS TUN / NETWORKEXTENSION |

IDs: `REQ-DEVICE-iphone-install` `REQ-DEVICE-tunnel-start` `REQ-P045`

## Pass 13 — Final HEAD re-audit after all fixes

| ID | Severity | Status | Canonical |
| --- | --- | --- | --- |
| `REQ-P046` | P2 | OPEN | DOCUMENTATION ТОЛЬКО ПОСЛЕ CODE |
| `REQ-P125` | P0 | OPEN | RELEASE READINESS MUST RE-AUDIT CURRENT HEAD AFTER CURSOR MODIFIES IT |

IDs: `REQ-P046` `REQ-P125`

## Full ID index

`REQ-P001` `REQ-P002` `REQ-P003` `REQ-P004` `REQ-P005` `REQ-P006` `REQ-P007` `REQ-P008` `REQ-P009` `REQ-P010` `REQ-P011` `REQ-P012` `REQ-P013` `REQ-P014` `REQ-P015` `REQ-P016` `REQ-P017` `REQ-P018` `REQ-P019` `REQ-P020` `REQ-P021` `REQ-P022` `REQ-P023` `REQ-P024` `REQ-P025` `REQ-P026` `REQ-P027` `REQ-P028` `REQ-P029` `REQ-P030` `REQ-P031` `REQ-P032` `REQ-P033` `REQ-P034` `REQ-P035` `REQ-P036` `REQ-P037` `REQ-P038` `REQ-P039` `REQ-P040` `REQ-P041` `REQ-P042` `REQ-P043` `REQ-P044` `REQ-P045` `REQ-P046` `REQ-P047` `REQ-P048` `REQ-P049` `REQ-P050` `REQ-P051` `REQ-P052` `REQ-P053` `REQ-P054` `REQ-P055` `REQ-P056` `REQ-P057` `REQ-P058` `REQ-P059` `REQ-P060` `REQ-P061` `REQ-P062` `REQ-P063` `REQ-P064` `REQ-P065` `REQ-P066` `REQ-P067` `REQ-P068` `REQ-P069` `REQ-P070` `REQ-P071` `REQ-P072` `REQ-P073` `REQ-P074` `REQ-P075` `REQ-P076` `REQ-P077` `REQ-P078` `REQ-P079` `REQ-P080` `REQ-P081` `REQ-P082` `REQ-P083` `REQ-P084` `REQ-P085` `REQ-P086` `REQ-P087` `REQ-P088` `REQ-P089` `REQ-P090` `REQ-P091` `REQ-P092` `REQ-P093` `REQ-P094` `REQ-P095` `REQ-P096` `REQ-P097` `REQ-P098` `REQ-P099` `REQ-P100` `REQ-P101` `REQ-P102` `REQ-P103` `REQ-P104` `REQ-P105` `REQ-P106` `REQ-P107` `REQ-P108` `REQ-P109` `REQ-P110` `REQ-P111` `REQ-P112` `REQ-P113` `REQ-P114` `REQ-P115` `REQ-P116` `REQ-P117` `REQ-P118` `REQ-P119` `REQ-P120` `REQ-P121` `REQ-P122` `REQ-P123` `REQ-P124` `REQ-P125` `REQ-P126` `REQ-P127` `REQ-P128` `REQ-P129` `REQ-P130` `REQ-P131` `REQ-P132` `REQ-P133` `REQ-P134` `REQ-P135` `REQ-P136` `REQ-P137` `REQ-P138` `REQ-P139` `REQ-P140` `REQ-PROTO-VLESS` `REQ-PROTO-VLESS-XHTTP` `REQ-PROTO-VLESS-PQ` `REQ-PROTO-VMESS` `REQ-PROTO-TROJAN` `REQ-PROTO-SS` `REQ-PROTO-SS2022` `REQ-PROTO-HY1` `REQ-PROTO-HY2` `REQ-PROTO-HY2-SAL` `REQ-PROTO-HY2-GECKO` `REQ-PROTO-TUIC` `REQ-PROTO-ANYTLS` `REQ-PROTO-SHADOWTLS` `REQ-PROTO-NAIVE` `REQ-PROTO-WG` `REQ-PROTO-AWG2` `REQ-PROTO-AWG30` `REQ-PROTO-AWG31` `REQ-PROTO-MASQUE-STD` `REQ-PROTO-WARP-MASQUE` `REQ-PROTO-MIERU-TCP` `REQ-PROTO-MIERU-UDP` `REQ-PROTO-MIERU-LE` `REQ-PROTO-SSH` `REQ-PROTO-SOCKS4` `REQ-PROTO-SOCKS5` `REQ-PROTO-HTTP` `REQ-PROTO-HTTPS` `REQ-PANEL-remnawave` `REQ-PANEL-3x-ui` `REQ-PANEL-x-ui` `REQ-PANEL-tx-ui` `REQ-PANEL-marzban` `REQ-PANEL-marzneshin` `REQ-PANEL-pasarguard` `REQ-PANEL-hiddify` `REQ-PANEL-libertea` `REQ-PANEL-s-ui` `REQ-PANEL-wg-easy` `REQ-PANEL-amnezia` `REQ-FMT-uri` `REQ-FMT-uri-list` `REQ-FMT-base64` `REQ-FMT-xray-obj` `REQ-FMT-xray-arr` `REQ-FMT-singbox` `REQ-FMT-clash` `REQ-FMT-mihomo` `REQ-FMT-stash` `REQ-FMT-wg-conf` `REQ-FMT-awg-conf` `REQ-FMT-mieru-json` `REQ-SHARED-TLS` `REQ-SHARED-MULTIPLEX` `REQ-SHARED-V2RAY-TRANSPORT` `REQ-SHARED-QUIC` `REQ-SHARED-DIAL` `REQ-SHARED-DNS` `REQ-SHARED-ROUTING` `REQ-BUILD-prepare-core` `REQ-BUILD-libbox-slices` `REQ-BUILD-go-pin` `REQ-BUILD-tag-profile` `REQ-BUILD-provenance` `REQ-HTTP-hwid-policy` `REQ-HTTP-redirect-origin` `REQ-HTTP-size-limit` `REQ-HTTP-keychain` `REQ-HTTP-schemes` `REQ-TEST-production-swift-e2e` `REQ-TEST-fuzz` `REQ-TEST-field-coverage` `REQ-TEST-fixture-provenance` `REQ-DEVICE-sfi-build` `REQ-DEVICE-iphone-install` `REQ-DEVICE-tunnel-start`

