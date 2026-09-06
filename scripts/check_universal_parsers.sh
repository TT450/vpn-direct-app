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
need "${FIX}/clash/clash_proxies.yaml"
need "${FIX}/mieru/mieru_profile.json"

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
clash = (root/"clash/clash_proxies.yaml").read_text()
assert "proxies:" in clash and "type: ss" in clash
mieru = (root/"mieru/mieru_profile.json").read_text().lower()
assert "profiles" in mieru and "serveraddress" in mieru
print("UNIVERSAL_FIXTURE_OK")
PY

if [[ "${fail}" -ne 0 ]]; then
  echo "check_universal_parsers FAILED" >&2
  exit 1
fi
echo "check_universal_parsers OK"
