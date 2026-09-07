#!/usr/bin/env bash
# Ensure PROTOCOL_MATRIX.md rows and core/protocol-matrix.json stay in sync.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$ROOT" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
json_path = root / "core/protocol-matrix.json"
md_path = root / "docs/core/PROTOCOL_MATRIX.md"
doc = json.loads(json_path.read_text())
ids = {p["id"] for p in doc.get("protocols", [])}
required = {
    "vless-baseline", "vless-xhttp", "vless-encryption",
    "vmess", "trojan", "shadowsocks", "hysteria2", "tuic", "anytls",
    "shadowtls", "naive", "wireguard", "amneziawg",
    "masque-connect-ip", "warp", "mieru", "socks-http-ssh",
    "masque-connect-udp", "tailscale", "openvpn",
}
missing = sorted(required - ids)
if missing:
    print("protocol-matrix.json missing ids:", ", ".join(missing), file=sys.stderr)
    sys.exit(1)
md = md_path.read_text()
for p in doc["protocols"]:
    name = p["name"]
    aliases = {
        "Shadowsocks": r"Shadowsocks",
        "Hysteria2": r"Hysteria",
        "MASQUE CONNECT-IP": r"MASQUE|CONNECT-IP",
        "MASQUE CONNECT-UDP": r"CONNECT-UDP",
        "OpenVPN / OpenConnect": r"OpenVPN",
        "SSH/SOCKS/HTTP": r"SSH/SOCKS/HTTP",
        "VLESS XHTTP": r"xhttp",
        "VLESS encryption": r"encryption",
        "NaiveProxy": r"Naive",
        "WARP": r"WARP",
        "ShadowTLS": r"ShadowTLS",
        "VLESS": r"VLESS",
    }
    pat = aliases.get(name, re.escape(name))
    if not re.search(pat, md, re.I):
        print(f"PROTOCOL_MATRIX.md missing visible mention for JSON name={name!r} id={p['id']}", file=sys.stderr)
        sys.exit(1)
    if p.get("status") == "tested":
        ev = p.get("evidence") or {}
        if not ev.get("interop") or not ev.get("device"):
            print(f"tested without evidence: {p['id']}", file=sys.stderr)
            sys.exit(1)
print("MATRIX_SYNC_OK", len(ids), "protocols")
PY
