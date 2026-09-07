#!/usr/bin/env python3
"""Generate docs/core/REMEDIATION_REQUIREMENTS.json from master_prompt_union snapshot."""
from __future__ import annotations

import json
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "core" / "REMEDIATION_REQUIREMENTS.json"

# Titles for ПРОБЛЕМА №1..№140 (latest restatement in master prompt union).
PROBLEMS = {
  "1": "WIREGUARD / AMNEZIAWG СЕЙЧАС СТРОЯТСЯ НЕПРАВИЛЬНО",
  "2": "WIREGUARD / AWG NORMALIZATION ТЕРЯЕТ ДАННЫЕ",
  "3": "AWG VERSION DETECTION СЕЙЧАС СЛОМАН",
  "4": "BATTLE TEST СЕЙЧАС НЕ ДОЛЖЕН МАСКИРОВАТЬ PRODUCTION BUGS",
  "5": "SILENT DROP В SingBoxGraphBuilder",
  "6": "XRAY / REMNAWAVE PARTIAL FAILURE",
  "7": "XRAY BALANCER НОРМАЛИЗУЕТСЯ НЕПРАВИЛЬНО",
  "8": "НЕПРАВИЛЬНЫЙ DEDUPE",
  "9": "3X-UI REAL JSON COMPATIBILITY",
  "10": "FIXTURES ДОЛЖНЫ БЫТЬ SOURCE-DERIVED, А НЕ PARSER-DERIVED",
  "11": "XRAY VLESS UNKNOWN TRANSPORT МОЖЕТ ТИХО СТАТЬ TCP",
  "12": "VLESS ENCRYPTION / PQ НЕ ДОЛЖНЫ ТИХО ИСЧЕЗАТЬ",
  "13": "XRAY FORMAT SUPPORT НЕ ДОЛЖЕН БЫТЬ ИСКУССТВЕННО УЗКИМ",
  "14": "URI LIST PARTIAL IMPORT ТОЖЕ SILENT",
  "15": "PROTOCOL SUPPORT != FORMAT SUPPORT",
  "16": "CLASH / MIHOMO — SYNTAX УЖЕ YAMS, НО SEMANTICS НЕ ПОЛНЫЕ",
  "17": "LIBERTEA FAILOVER SEMANTICS",
  "18": "HIDDIFY SMART GROUPS / ROUTING",
  "19": "ROUTING HEADER / PANEL ROUTING СЕЙЧАС МОЖЕТ ТОЛЬКО СОХРАНЯТЬСЯ КАК METADATA",
  "20": "HTTP SUBSCRIPTION LAYER — НЕ СЛАТЬ HWID ВСЕМ ПОДРЯД",
  "21": "REDIRECT HEADER LEAK",
  "22": "HTTP ERROR BODY / REMNAWAVE RESPONSE RULES",
  "23": "SUBSCRIPTION DOWNLOAD SIZE LIMIT",
  "24": "URL SCHEME / FETCH VALIDATION",
  "25": "KEYCHAIN WRITE RESULT",
  "26": "LEGACY NormalizedNode.outbound EARLY RETURN",
  "27": "rawExtensions СЕЙЧАС LOSSY",
  "28": "CompatibilityFieldPolicy НЕ ДОЛЖЕН БЫТЬ ТОЛЬКО HEURISTIC",
  "29": "VLESS ПОЛНОСТЬЮ",
  "30": "HYSTERIA / HYSTERIA2",
  "31": "MIERU",
  "32": "MASQUE / WARP",
  "33": "SHADOWTLS CHAINS",
  "34": "NAIVEPROXY",
  "35": "SSH / SOCKS / HTTP",
  "36": "NATIVE SING-BOX JSON",
  "37": "CONTENT DETECTOR",
  "38": "PANEL FINGERPRINTING",
  "39": "PANEL MATRIX НЕ ДОЛЖЕН ГОВОРИТЬ “INTEROP TRUE” БЕЗ REAL INTEROP",
  "40": "PANEL-SPECIFIC AUDIT",
  "41": "TEST COVERAGE — ACTUAL PRODUCTION SWIFT",
  "42": "TRUE FUZZ / PROPERTY TESTS",
  "43": "LIBBOX BUILD ДОЛЖЕН ПРОВЕРЯТЬ PLATFORM SLICES",
  "44": "prepare_core ДОЛЖЕН БЫТЬ НАСТОЯЩИМ FAIL-CLOSED",
  "45": "IOS TUN / NETWORKEXTENSION",
  "46": "DOCUMENTATION ТОЛЬКО ПОСЛЕ CODE",
  "47": "3X-UI SUBSCRIPTION OPTIONS — MUX / FINALMASK / ROUTING",
  "48": "TRANSPORT OPTIONS НЕЛЬЗЯ СВОДИТЬ К path/host/service_name",
  "49": "HYSTERIA2 SERVER_PORTS / PORT HOPPING",
  "50": "HYSTERIA2 / QUIC ADVANCED OPTIONS",
  "51": "TUIC v5 ПОДДЕРЖАН НЕ ПОЛНОСТЬЮ",
  "52": "VLESS MULTIPLEX / MUX",
  "53": "VMESS ADVANCED OUTBOUND OPTIONS",
  "54": "SHADOWSOCKS / SS2022 ADVANCED OPTIONS",
  "55": "HIDDIFY MUX / FRAGMENT / CLIENT OPTIONS",
  "56": "TLS MODEL СЕЙЧАС СЛИШКОМ УЗКИЙ",
  "57": "NAIVEPROXY BUILDER СЕЙЧАС НЕДОСТАТОЧЕН",
  "58": "REMNAWAVE RESPONSE TYPES — ПОЛНАЯ МАТРИЦА",
  "59": "REMNAWAVE ADDITIONAL PATHS МОГУТ БЫТЬ DISABLED",
  "60": "REMNAWAVE USER-AGENT × RESPONSE RULE MATRIX",
  "61": "HIDDIFY METADATA В BODY НЕ ДОЛЖНА ЛОМАТЬ DETECTOR",
  "62": "S-UI NATIVE SING-BOX TOPOLOGY",
  "63": "CLASH / MIHOMO PROXY-PROVIDERS",
  "64": "CLASH NESTED GROUPS / GRAPH VALIDATION",
  "65": "MARZBAN RICH TRANSPORT OUTPUT",
  "66": "PANEL COMPATIBILITY ДОЛЖНА БЫТЬ 4-D MATRIX",
  "67": "CROSS-FORMAT SEMANTIC EQUIVALENCE TESTS",
  "68": "DEFAULT VALUE DRIFT",
  "69": "TYPE COERCION / STRINGIFICATION",
  "70": "KNOWN FIELD НЕ РАВНО SUPPORTED FIELD",
  "71": "NO SILENT SEMANTIC DEGRADATION — GLOBAL INVARIANT",
  "72": "НЕ ОСТАНАВЛИВАТЬСЯ НА ИЗВЕСТНОМ СПИСКЕ",
  "73": "SingBoxGraphBuilder ВСЁ ЕЩЁ SILENTLY DROPS ENDPOINTS",
  "74": "Clash/Xray FIX ПЕРЕШЁЛ ИЗ SILENT DROP В ALL-OR-NOTHING",
  "75": "NormalizedLocationStrategy СЛИШКОМ БЕДНЫЙ",
  "76": "GraphBuilder ПРИНУДИТЕЛЬНО ДЕЛАЕТ ЛЮБУЮ MULTI-NODE LOCATION URLTEST",
  "77": "GLOBAL AUTO ОБХОДИТ LOCATION/GROUP SEMANTICS",
  "78": "DETOUR FORWARD REFERENCE СЛОМАН ДЛЯ SINGLE LOCATION",
  "79": "MISSING DETOUR REFERENCE SILENTLY IGNORED",
  "80": "NODE NAME НЕ ЯВЛЯЕТСЯ НАДЁЖНЫМ REFERENCE ID",
  "81": "FIXED DNS 1.1.1.1 ЛОМАЕТ PANEL/NATIVE DNS SEMANTICS",
  "82": "GLOBAL `prefer_ipv4` МОЖЕТ ЛОМАТЬ IPv6/DUAL-STACK",
  "83": "TUN MTU=9000 HARDCODED",
  "84": "PRIVATE NETWORKS ВСЕГДА ИДУТ DIRECT",
  "85": "CONFIG VALIDATION И MIGRATION СТОЯТ В НЕПРАВИЛЬНОМ ПОРЯДКЕ",
  "86": "NATIVE/PANEL ROUTING METADATA НЕ ДОХОДИТ ДО FINAL ROUTE",
  "87": "Xray BALANCER В ТЕКУЩЕМ HEAD ВСЁ ЕЩЁ СВЕДЁН К hasBalancers",
  "88": "Xray PROFILE PARTIAL LOSS СЕЙЧАС ABORTS WHOLE PROFILE",
  "89": "Xray PROTOCOL FILTER СЛИШКОМ УЗКИЙ",
  "90": "Xray DEDUPE ЕЩЁ НЕ ПОЛНЫЙ",
  "91": "Xray flattenOutboundFields LOSSY TYPE COERCION ПРЯМО В CURRENT CODE",
  "92": "Xray `firstString` ТЕРЯЕТ MULTI-VALUE SEMANTICS",
  "93": "CONTENT DETECTOR ВСЁ ЕЩЁ HEURISTIC SUBSTRING, НЕ STRUCTURAL JSON",
  "94": "XRAY TOP-LEVEL OBJECT НЕ DETECTED",
  "95": "BASE64 ENCODED JSON/YAML DETECTION LOGIC BROKEN",
  "96": "HIDDIFY/PANEL COMMENT PREFIX BEFORE JSON BREAKS PREFIX DETECTION",
  "97": "OUT-OF-SCOPE PROTOCOLS ARE NOT RECOGNIZED EXPLICITLY",
  "98": "SubscriptionHTTP HWID PRIVACY FIX ВСЁ ЕЩЁ НЕ РЕШАЕТ FIRST REQUEST LEAK",
  "99": "REDIRECT POLICY СРАВНИВАЕТ HOST, А НЕ ORIGIN",
  "100": "REDIRECT STRIPPING НЕПОЛНЫЙ",
  "101": "SUBSCRIPTION SIZE LIMIT CHECK HAPPENS TOO LATE",
  "102": "HTTP 4xx/451 BODY LOST BEFORE PANEL ERROR CLASSIFICATION",
  "103": "Keychain FAILURE HANDLING ТОЛЬКО ЛОГИРУЕТ",
  "104": "HWID USERDEFAULTS + KEYCHAIN CONSISTENCY IS NOT TRANSACTIONAL",
  "105": "build_libbox RECORDS CORE SHA BEFORE prepare_core",
  "106": "build_libbox МОЖЕТ ПОДХВАТИТЬ СТАРЫЙ ROOT Libbox",
  "107": "PLATFORM SLICE CHECK ПРОВЕРЯЕТ FAMILY, НЕ EVERY REQUESTED PLATFORM",
  "108": "gomobile init ВСЁ ЕЩЁ `|| true`",
  "109": "GO VERSION PIN ТОЛЬКО ПЕЧАТАЕТСЯ, НЕ ENFORCED",
  "110": "BUILD PROFILE TAG FILE MISSING CAN SILENTLY FALL BACK TO INCOMPLETE TAG SET",
  "111": "prepare_core APPLY MODE НЕ PROVES HEAD == SING_BOX_REV",
  "112": "prepare_core --verify ПРОВЕРЯЕТ ПОЧТИ ТОЛЬКО MIERU",
  "113": "prepare_core МОЖЕТ MUTATE go.mod ЧЕРЕЗ `go get` DURING BUILD",
  "114": "OVERLAY / DEPENDENCY VERSION HAS TWO SOURCES OF TRUTH",
  "115": "FINAL CORE TREE PROVENANCE NOT STRONG ENOUGH",
  "116": "FIXED URLTEST PROBE GOOGLE GSTATIC IS A HIDDEN GLOBAL DEPENDENCY",
  "117": "URLTEST DEFAULTS MAY NOT MATCH PANEL SEMANTICS",
  "118": "GraphBuilder HAS NO ENDPOINT COLLECTION FOR MODERN ENDPOINT TYPES",
  "119": "MIGRATOR CAN CHANGE TAGS/SCHEMA AFTER GRAPH REFERENCES WERE BUILT",
  "120": "LOCATION KIND/COMMENT STILL REMNAWAVE-CENTRIC",
  "121": "SHARE NODE ALWAYS MARKED `.country`",
  "122": "COUNTRY/UI GROUPING AND CONNECTION TOPOLOGY ARE MIXED",
  "123": "CORE ERROR AFTER LibboxCheckConfig IS THROWN AS RAW NSError",
  "124": "NO FINAL SECRET-SAFE CONFIG DIAGNOSTIC BOUNDARY",
  "125": "RELEASE READINESS MUST RE-AUDIT CURRENT HEAD AFTER CURSOR MODIFIES IT",
  "126": "HYSTERIA BUILDER RE-PARSES `source` AND CAN BYPASS NORMALIZED STATE",
  "127": "MASQUE BUILDER CURRENTLY CONFLATES GENERIC MASQUE WITH WARP",
  "128": "MIERU CURRENT BUILDER SILENTLY DEFAULTS TRANSPORT TO TCP",
  "129": "SSH BUILDER SILENTLY DEFAULTS USER TO `root`",
  "130": "XHTTP NUMERIC/STRUCTURED FIELDS EMITTED AS STRINGS",
  "131": "BOOLEAN PARSING IS AD-HOC (`\"1\"` ONLY)",
  "132": "UNKNOWN TRANSPORT CAN STILL DISAPPEAR INTO “NO TRANSPORT”",
  "133": "DO NOT ASSUME ENDPOINT TAG WORKS IN SELECTOR/URLTEST UNTIL PINNED CORE PROVES IT",
  "134": "AWG VERSION INFERENCE MUST NOT BE LOCKED FROM GUESSED FIELD BOUNDARIES",
  "135": "WARP REGISTRATION API IS NOT A BLOCKER FOR EXISTING-IDENTITY IMPORT",
  "136": "NormalizedNode EQUATABLE IGNORES `outbound`",
  "137": "`source` IS INCLUDED IN NODE EQUALITY EVEN THOUGH IT SHOULD BE PROVENANCE",
  "138": "LEGACY `outbound` EARLY RETURN BYPASSES FAIL-CLOSED UNKNOWN FIELD CHECK",
  "139": "DEFAULTS MUST DISTINGUISH “FIELD ABSENT” FROM “PARSER LOST FIELD”",
  "140": "PROTOCOL BUILDERS NEED SCHEMA-DRIVEN REQUIRED/CONDITIONAL FIELD VALIDATION"
}

IMPLEMENTED_P = {
  "1": "Library/Service/VPNDirect/WireGuardConfAdapter.swift;Library/Service/VPNDirectProtocolBuilders.swift;Library/Service/VPNDirect/UniversalOutboundBuilder.swift;Library/Service/VPNDirect/SingBoxGraphBuilder.swift",
  "2": "Library/Service/VPNDirect/WireGuardConfAdapter.swift;Library/Service/VPNDirect/NormalizedNode.swift;Library/Service/VPNDirectProtocolBuilders.swift",
  "3": "Library/Service/VPNDirectProtocolBuilders.swift",
  "4": "tests/VPNDirectParserPackage/Sources/BattleParse/BattleParse.swift;Library/Service/VPNDirect/WireGuardConfAdapter.swift",
  "5": "Library/Service/VPNDirect/SingBoxGraphBuilder.swift",
  "6": "Library/Service/VPNDirect/XrayJSONAdapter.swift;tests/VPNDirectParserPackage/Tests/XrayAndFailClosedTests.swift",
  "7": "Library/Service/VPNDirect/XrayJSONAdapter.swift;tests/fixtures/panels/remnawave/xray_balancer_random_unsupported.json",
  "8": "Library/Service/VPNDirect/NormalizedNode.swift;Library/Service/VPNDirect/XrayJSONAdapter.swift"
}


def classify_problem(n: int, title: str):
    t = title.upper()
    severity = "P1"
    plan_pass = 1
    area = "Library/Service/VPNDirect"
    acceptance = f"Problem #{n} resolved with regression coverage: {title}"

    if n <= 8:
        severity = "P0"
        plan_pass = 2 if n <= 4 else (1 if n == 5 else 2)
        if n <= 4:
            area = "Library/Service/VPNDirect/WireGuardConfAdapter.swift;Library/Service/VPNDirectProtocolBuilders.swift;Library/Service/VPNDirect/UniversalOutboundBuilder.swift"
        elif n == 5:
            area = "Library/Service/VPNDirect/SingBoxGraphBuilder.swift"
        elif n in (6, 7):
            area = "Library/Service/VPNDirect/XrayJSONAdapter.swift"
        else:
            area = "Library/Service/VPNDirect/NormalizedNode.swift;Library/Service/VPNDirect/XrayJSONAdapter.swift"
    elif n in (9, 10, 38, 39, 40, 47, 55, 58, 59, 60, 61, 62, 65, 66) or "PANEL" in t or "3X-UI" in t or "REMNAWAVE" in t or "HIDDIFY" in t or "MARZBAN" in t or "LIBERTEA" in t or "S-UI" in t:
        plan_pass = 6
        area = "Library/Service/VPNDirect;docs/compatibility/panels;tests/fixtures/panels"
        severity = "P0" if n in (9, 58) else "P1"
    elif any(k in t for k in ("HTTP", "HWID", "REDIRECT", "KEYCHAIN", "SUBSCRIPTION SIZE", "URL SCHEME", "4XX", "451")):
        plan_pass = 8
        area = "Library/Service/VPNDirect;SubscriptionHTTP"
        severity = "P0" if any(k in t for k in ("HWID", "REDIRECT", "KEYCHAIN")) else "P1"
    elif any(k in t for k in ("LIBBOX", "PREPARE_CORE", "GOMOBILE", "GO VERSION", "BUILD PROFILE", "PROVENANCE", "OVERLAY", "PLATFORM SLICE")):
        plan_pass = 9
        area = "scripts;core"
        severity = "P0" if "PREPARE_CORE" in t or "LIBBOX" in t else "P1"
    elif any(k in t for k in ("TEST", "FUZZ", "FIXTURE", "EQUIVALENCE", "FIELD", "COVERAGE")):
        plan_pass = 10
        area = "tests/VPNDirectParserPackage"
        severity = "P1"
    elif any(k in t for k in ("IOS TUN", "NETWORKEXTENSION", "DEVICE", "IPHONE")):
        plan_pass = 12
        area = "Library/Network;SFI"
        severity = "P0"
    elif n == 125 or "RE-AUDIT" in t or "DOCUMENTATION" in t:
        plan_pass = 13 if n == 125 else 0
        area = "docs/core"
        severity = "P2" if "DOCUMENTATION" in t else "P1"
    elif any(k in t for k in ("WG", "WIREGUARD", "AWG", "AMNEZIA")):
        plan_pass = 2
        area = "Library/Service/VPNDirectProtocolBuilders.swift;Library/Service/VPNDirect/WireGuardConfAdapter.swift"
        severity = "P0"
    elif any(k in t for k in ("GRAPH", "ENDPOINT", "DETOUR", "URLTEST", "LOCATION", "SILENT DROP", "BALANCER", "TOPOLOGY", "AUTO")):
        plan_pass = 1
        area = "Library/Service/VPNDirect/SingBoxGraphBuilder.swift"
        severity = "P0" if "SILENT" in t or "DROP" in t else "P1"
    elif any(k in t for k in ("MIGRAT", "VALIDAT", "EXTENSION", "CHECKCONFIG", "NSERROR", "SECRET")):
        plan_pass = 3
        area = "Library/Network/ExtensionProfile.swift;Library/Service/VPNDirect"
        severity = "P0" if "MIGRAT" in t else "P1"
    elif any(k in t for k in ("NORMALIZED", "RAWEXTENSIONS", "OUTBOUND", "EQUATABLE", "TYPED", "DEFAULT")):
        plan_pass = 4
        area = "Library/Service/VPNDirect/NormalizedNode.swift"
        severity = "P1"
    elif any(k in t for k in ("VLESS", "VMESS", "TROJAN", "SHADOW", "HYSTERIA", "TUIC", "NAIVE", "MIERU", "MASQUE", "WARP", "SSH", "SOCKS", "HTTP PROXY", "PROTOCOL", "XHTTP", "MULTIPLEX", "TLS")):
        plan_pass = 5
        area = "Library/Service/VPNDirect/UniversalOutboundBuilder.swift;Library/Service/VPNDirectProtocolBuilders.swift"
        severity = "P0"
    elif any(k in t for k in ("CLASH", "XRAY", "URI", "BASE64", "DETECTOR", "FORMAT", "SING-BOX JSON", "YAML", "CONF")):
        plan_pass = 7
        area = "Library/Service/VPNDirect"
        severity = "P0" if "SILENT" in t or "DETECTOR" in t else "P1"
    elif any(k in t for k in ("DNS", "ROUTING", "MTU", "IPV4", "PRIVATE NETWORK")):
        plan_pass = 1
        area = "Library/Service/VPNDirect/SingBoxGraphBuilder.swift"
        severity = "P1"

    if n in (73, 74, 76, 77, 78, 79, 80, 118):
        plan_pass, severity, area = 1, "P0", "Library/Service/VPNDirect/SingBoxGraphBuilder.swift"
    if n in (85, 119, 123, 124):
        plan_pass, severity = 3, "P0"
        area = "Library/Network/ExtensionProfile.swift;Library/Service/VPNDirect"
    if n in (1, 2, 3, 4, 134):
        plan_pass, severity = 2, "P0"
    if n == 46:
        plan_pass, severity = 13, "P2"
    if n == 125:
        plan_pass, severity = 13, "P0"
    return severity, plan_pass, area, acceptance


def build_requirements():
    reqs = []
    for n in range(1, 141):
        title = PROBLEMS[str(n)]
        severity, plan_pass, area, acceptance = classify_problem(n, title)
        status = "OPEN"
        if str(n) in IMPLEMENTED_P:
            status = "IMPLEMENTED_UNVERIFIED"
            area = IMPLEMENTED_P[str(n)]
        if n == 85:
            status = "IMPLEMENTED_UNVERIFIED"
            area = "Library/Network/ExtensionProfile.swift"
        reqs.append({
            "id": f"REQ-P{n:03d}",
            "canonical": title,
            "sources": [f"v08:#{n}"],
            "severity": severity,
            "plan_pass": plan_pass,
            "area": area,
            "acceptance": acceptance,
            "deps": [],
            "status": status,
        })

    PROTOS = [
        ("VLESS", "VLESS base transports (TCP/WS/gRPC/HTTPUpgrade/Reality)"),
        ("VLESS-XHTTP", "VLESS XHTTP (+ Reality) field-complete"),
        ("VLESS-PQ", "VLESS encryption / post-quantum fields fail-closed"),
        ("VMESS", "VMess outbound + advanced options"),
        ("TROJAN", "Trojan outbound field-complete"),
        ("SS", "Shadowsocks classic"),
        ("SS2022", "Shadowsocks 2022"),
        ("HY1", "Hysteria v1"),
        ("HY2", "Hysteria2"),
        ("HY2-SAL", "Hysteria2 Salamander"),
        ("HY2-GECKO", "Hysteria2 Gecko"),
        ("TUIC", "TUIC v5"),
        ("ANYTLS", "AnyTLS"),
        ("SHADOWTLS", "ShadowTLS chains"),
        ("NAIVE", "NaiveProxy"),
        ("WG", "WireGuard endpoints schema"),
        ("AWG2", "AmneziaWG 2.x"),
        ("AWG30", "AmneziaWG 3.0"),
        ("AWG31", "AmneziaWG 3.1+"),
        ("MASQUE-STD", "MASQUE CONNECT-IP standard"),
        ("WARP-MASQUE", "WARP via MASQUE (existing identity)"),
        ("MIERU-TCP", "Mieru TCP"),
        ("MIERU-UDP", "Mieru UDP"),
        ("MIERU-LE", "Mieru Low Entropy"),
        ("SSH", "SSH outbound"),
        ("SOCKS4", "SOCKS4/4a"),
        ("SOCKS5", "SOCKS5"),
        ("HTTP", "HTTP proxy"),
        ("HTTPS", "HTTPS proxy"),
    ]
    for slug, canon in PROTOS:
        reqs.append({
            "id": f"REQ-PROTO-{slug}",
            "canonical": canon,
            "sources": [f"master:PASS5:{slug}"],
            "severity": "P0",
            "plan_pass": 5,
            "area": "Library/Service/VPNDirect/UniversalOutboundBuilder.swift;Library/Service/VPNDirectProtocolBuilders.swift",
            "acceptance": f"Protocol family {slug} parses, builds, and validates against Core without silent field loss",
            "deps": ["REQ-P001", "REQ-P005"] if slug in ("WG", "AWG2", "AWG30", "AWG31") else [],
            "status": "IMPLEMENTED_UNVERIFIED" if slug in ("WG", "AWG2", "AWG30", "AWG31") else "OPEN",
        })

    PANELS = [
        "remnawave", "3x-ui", "x-ui", "tx-ui", "marzban", "marzneshin",
        "pasarguard", "hiddify", "libertea", "s-ui", "wg-easy", "amnezia",
    ]
    for p in PANELS:
        reqs.append({
            "id": f"REQ-PANEL-{p}",
            "canonical": f"Panel exhaustive gate: {p}",
            "sources": [f"master:PASS6:{p}"],
            "severity": "P0",
            "plan_pass": 6,
            "area": f"docs/compatibility/panels/{p};tests/fixtures/panels/{p};interop/panels/{p}",
            "acceptance": f"Panel {p}: real shapes + fixtures + fail-closed unknowns + matrix honesty",
            "deps": [],
            "status": "OPEN",
        })

    FMTS = [
        ("uri", "Direct share URI"),
        ("uri-list", "Plain URI list subscription"),
        ("base64", "Base64 URI list"),
        ("xray-obj", "Xray JSON object"),
        ("xray-arr", "Xray JSON array"),
        ("singbox", "Native sing-box JSON"),
        ("clash", "Clash YAML"),
        ("mihomo", "Mihomo YAML"),
        ("stash", "Stash YAML"),
        ("wg-conf", "WireGuard .conf"),
        ("awg-conf", "AmneziaWG .conf"),
        ("mieru-json", "Mieru JSON"),
    ]
    for slug, canon in FMTS:
        reqs.append({
            "id": f"REQ-FMT-{slug}",
            "canonical": canon,
            "sources": [f"master:PASS7:{slug}"],
            "severity": "P0",
            "plan_pass": 7,
            "area": "Library/Service/VPNDirect",
            "acceptance": f"Format {slug} detected, parsed, normalized, and graph-built without silent loss",
            "deps": [],
            "status": "IMPLEMENTED_UNVERIFIED" if slug in ("wg-conf", "awg-conf") else "OPEN",
        })

    SHARED = [
        ("TLS", "Shared TLS model (SNI/ALPN/ECH/Reality/utls)"),
        ("MULTIPLEX", "Shared multiplex / mux options"),
        ("V2RAY-TRANSPORT", "Shared V2Ray transports (ws/grpc/httpupgrade/xhttp/h2)"),
        ("QUIC", "Shared QUIC / HY2 / TUIC options"),
        ("DIAL", "Shared dial / bind / domain strategy"),
        ("DNS", "Shared DNS semantics (not hardcoded)"),
        ("ROUTING", "Shared routing / bypass / panel routing"),
    ]
    for slug, canon in SHARED:
        reqs.append({
            "id": f"REQ-SHARED-{slug}",
            "canonical": canon,
            "sources": [f"master:SHARED:{slug}"],
            "severity": "P0",
            "plan_pass": 4 if slug in ("TLS", "MULTIPLEX", "V2RAY-TRANSPORT", "QUIC", "DIAL") else 1,
            "area": "Library/Service/VPNDirect",
            "acceptance": f"Shared capability {slug} is typed, fail-closed, and covered by fixtures",
            "deps": [],
            "status": "OPEN",
        })

    BUILDS = [
        ("prepare-core", "prepare_core fail-closed apply/verify"),
        ("libbox-slices", "Libbox platform slice completeness"),
        ("go-pin", "Go toolchain pin enforced"),
        ("tag-profile", "Build tag profile exactness"),
        ("provenance", "Core tree provenance / SHA honesty"),
    ]
    for slug, canon in BUILDS:
        reqs.append({
            "id": f"REQ-BUILD-{slug}",
            "canonical": canon,
            "sources": [f"master:PASS9:{slug}"],
            "severity": "P0",
            "plan_pass": 9,
            "area": "scripts;core",
            "acceptance": f"Build gate {slug} fails closed with evidence",
            "deps": [],
            "status": "OPEN",
        })

    HTTPS = [
        ("hwid-policy", "HWID sent only to allowlisted panels"),
        ("redirect-origin", "Redirect policy compares origin not host"),
        ("size-limit", "Subscription download size limit before body buffer"),
        ("keychain", "Keychain write failures are fail-closed"),
        ("schemes", "URL scheme / fetch validation"),
    ]
    for slug, canon in HTTPS:
        reqs.append({
            "id": f"REQ-HTTP-{slug}",
            "canonical": canon,
            "sources": [f"master:PASS8:{slug}"],
            "severity": "P0",
            "plan_pass": 8,
            "area": "Library/Service;SubscriptionHTTP",
            "acceptance": f"HTTP privacy/security gate: {canon}",
            "deps": [],
            "status": "OPEN",
        })

    TESTS = [
        ("production-swift-e2e", "Production Swift path e2e (not BattleParse-only)"),
        ("fuzz", "True fuzz / property tests"),
        ("field-coverage", "Protocol field coverage matrix"),
        ("fixture-provenance", "Fixtures are source-derived with provenance"),
    ]
    for slug, canon in TESTS:
        reqs.append({
            "id": f"REQ-TEST-{slug}",
            "canonical": canon,
            "sources": [f"master:PASS10:{slug}"],
            "severity": "P1",
            "plan_pass": 10,
            "area": "tests/VPNDirectParserPackage;tests/fixtures",
            "acceptance": f"Test gate: {canon}",
            "deps": [],
            "status": "OPEN",
        })

    DEVICES = [
        ("sfi-build", "SFI / Packet Tunnel compile with embedded Libbox", "OPEN", 11),
        ("iphone-install", "Physical iPhone install via Xcode/devicectl", "EXTERNAL_BLOCKED", 12),
        ("tunnel-start", "Packet Tunnel starts; Libbox setup; TUN up on known-good config", "OPEN", 12),
    ]
    for slug, canon, status, pp in DEVICES:
        reqs.append({
            "id": f"REQ-DEVICE-{slug}",
            "canonical": canon,
            "sources": [f"master:PASS12:{slug}", "v08:#14"] if slug == "iphone-install" else [f"master:PASS{pp}:{slug}"],
            "severity": "P0",
            "plan_pass": pp,
            "area": "Library/Network/ExtensionProfile.swift;SFI" if slug != "iphone-install" else "device;interop/evidence",
            "acceptance": f"Device gate: {canon}",
            "deps": ["REQ-BUILD-libbox-slices"] if slug == "sfi-build" else (["REQ-DEVICE-sfi-build"] if slug == "iphone-install" else ["REQ-DEVICE-iphone-install"]),
            "status": status,
        })
    return reqs


def main() -> None:
    reqs = build_requirements()
    doc = {
        "meta": {
            "generated": date.today().isoformat(),
            "source": "master_prompt_union",
            "count": len(reqs),
        },
        "requirements": reqs,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(reqs)} requirements)")


if __name__ == "__main__":
    main()
