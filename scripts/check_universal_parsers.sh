#!/usr/bin/env bash
# Structural asserts for universal share-link / clash / mieru / panel fixtures.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="${ROOT}/tests/fixtures/regression"
PANELS="${ROOT}/tests/fixtures/panels"
fail=0

need() {
  if [[ ! -f "$1" ]]; then echo "MISSING $1" >&2; fail=1; else echo "OK $1"; fi
}

need "${FIX}/vmess/vmess_share.uri"
need "${FIX}/trojan/trojan_share.uri"
need "${FIX}/ss/ss_share.uri"
need "${FIX}/tuic/tuic_share.uri"
need "${FIX}/anytls/anytls_share.uri"
need "${FIX}/wg/wireguard_share.uri"
need "${FIX}/socks/socks_share.uri"
need "${FIX}/ssh/ssh_share.uri"
need "${FIX}/http/http_proxy_share.uri"
need "${FIX}/naive/naive_share.uri"
need "${FIX}/shadowtls/shadowtls_share.uri"
need "${FIX}/clash/clash_proxies.yaml"
need "${FIX}/clash/clash_reality_ws.yaml"
need "${FIX}/mieru/mieru_profile.json"
need "${FIX}/mieru/client.json"
need "${PANELS}/3x-ui/xray_single_flat.json"

python3 - <<PY || fail=1
from pathlib import Path
import json
root = Path(r"${FIX}")
panels = Path(r"${PANELS}")

def head(p):
    return p.read_text().strip().splitlines()[0].lower()

assert head(root/"vmess/vmess_share.uri").startswith("vmess://")
assert head(root/"trojan/trojan_share.uri").startswith("trojan://")
assert head(root/"ss/ss_share.uri").startswith("ss://")
assert head(root/"tuic/tuic_share.uri").startswith("tuic://")
assert head(root/"anytls/anytls_share.uri").startswith("anytls://")
assert head(root/"wg/wireguard_share.uri").startswith("wireguard://")
assert head(root/"socks/socks_share.uri").startswith("socks")
assert head(root/"ssh/ssh_share.uri").startswith("ssh://")
assert head(root/"http/http_proxy_share.uri").startswith("http-proxy://")
assert head(root/"naive/naive_share.uri").startswith("naive")
assert head(root/"shadowtls/shadowtls_share.uri").startswith("shadowtls://")

# Detector must recognize registry schemes (mirror of VPNDirectContentDetector.containsShareScheme).
schemes = [
    "vless://", "vmess://", "trojan://", "ss://",
    "hysteria://", "hysteria2://", "hy2://", "tuic://", "anytls://",
    "wireguard://", "wg://", "awg://", "socks://", "socks5://", "socks4://",
    "ssh://", "shadowtls://",
    "naive://", "naive+https://", "naive+quic://",
    "http-proxy://", "https-proxy://",
]
for sample in [
    head(root/"naive/naive_share.uri"),
    head(root/"shadowtls/shadowtls_share.uri"),
    head(root/"http/http_proxy_share.uri"),
]:
    assert any(s in sample for s in schemes), sample
print("UNIVERSAL_FIXTURE_OK")
print("DETECTOR_SCHEME_COVERAGE_OK")
clash = (root/"clash/clash_proxies.yaml").read_text()
assert "proxies:" in clash and "type: ss" in clash
nested = (root/"clash/clash_reality_ws.yaml").read_text()
assert "reality-opts:" in nested and "ws-opts:" in nested and "grpc-opts:" in nested
assert "public-key:" in nested and "grpc-service-name:" in nested
mieru = (root/"mieru/mieru_profile.json").read_text().lower()
assert "profiles" in mieru and "serveraddress" in mieru
assert "transport" in mieru
client = (root/"mieru/client.json").read_text().lower()
assert '"type": "mieru"' in client or '"type":"mieru"' in client.replace(" ", "")

# Current 3x-ui one-client JSON response is one config object (not necessarily an array),
# and current VLESS generator uses flat settings address/port/id.
flat = json.loads((panels/"3x-ui/xray_single_flat.json").read_text())
assert isinstance(flat, dict)
outbounds = flat.get("outbounds", [])
vless = next(o for o in outbounds if o.get("protocol") == "vless")
settings = vless["settings"]
assert all(k in settings for k in ("address", "port", "id"))
assert "vnext" not in settings
headers = vless["streamSettings"]["wsSettings"]["headers"]
assert headers.get("X-Panel-Test") == "preserve-me"
print("CLASH_NESTED_FIXTURE_OK")
print("MIERU_CLIENT_FIXTURE_OK")
print("THREEXUI_SINGLE_OBJECT_FIXTURE_OK")
PY

if [[ "${fail}" -ne 0 ]]; then
  echo "check_universal_parsers FAILED" >&2
  exit 1
fi
echo "check_universal_parsers OK"
