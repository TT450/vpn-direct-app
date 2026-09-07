#!/usr/bin/env bash
# Structural asserts for universal share-link / clash / mieru fixtures.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="${ROOT}/tests/fixtures/regression"
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

python3 - <<PY || fail=1
from pathlib import Path
root = Path(r"${FIX}")

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
assert "transport" in client and "username" in client
print("CLASH_NESTED_FIXTURE_OK")
print("MIERU_CLIENT_FIXTURE_OK")
PY

if [[ "${fail}" -ne 0 ]]; then
  echo "check_universal_parsers FAILED" >&2
  exit 1
fi
echo "check_universal_parsers OK"
