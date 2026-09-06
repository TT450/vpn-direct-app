#!/usr/bin/env bash
# Validate regression fixtures (shape + capability JSON + AWG multi-peer).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="${ROOT}/tests/fixtures/regression"
CORE="${ROOT}/core/sing-box"

fail=0

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "MISSING $1" >&2
    fail=1
  else
    echo "OK $1"
  fi
}

require_file "${FIX}/vless_ws_reality.uri"
require_file "${FIX}/vless_xhttp.uri"
require_file "${FIX}/vless_encryption_pq.uri"
require_file "${FIX}/awg2_sample.conf"
require_file "${FIX}/awg3_multipeer.conf"
require_file "${FIX}/masque_cloudflare.json"
require_file "${FIX}/xray_vless_xhttp.json"
require_file "${FIX}/capability_core.json"
require_file "${FIX}/capability_stock.json"

python3 - <<PY || fail=1
import json, pathlib, sys
root = pathlib.Path(r"${FIX}")
for name in ("masque_cloudflare.json", "xray_vless_xhttp.json", "capability_core.json", "capability_stock.json"):
    obj = json.loads((root / name).read_text())
    print("JSON_OK", name)

core = json.loads((root / "capability_core.json").read_text())
stock = json.loads((root / "capability_stock.json").read_text())
assert core["magic"] == "VPN_DIRECT_CORE" and core["api"] == 1
assert core["xhttp"] is True and stock["xhttp"] is False
assert core["awg"] is True and stock["awg"] is False
assert "gecko" in core["hysteria2Obfuscations"]
assert "gecko" not in stock["hysteria2Obfuscations"]
print("CAPABILITY_OK core vs stock fail-closed shape")

for name in ("vless_ws_reality.uri", "vless_xhttp.uri", "vless_encryption_pq.uri"):
    text = (root / name).read_text().strip()
    assert text.startswith("vless://"), name
    print("URI_OK", name)

xhttp = (root / "vless_xhttp.uri").read_text().lower()
assert "type=xhttp" in xhttp or "type=splithttp" in xhttp
print("XHTTP_URI_OK (must error when supportsXHTTP=false — no httpupgrade downgrade)")

conf = (root / "awg2_sample.conf").read_text()
assert "[Interface]" in conf and "[Peer]" in conf and "Jc =" in conf
print("CONF_OK awg2_sample.conf")

multi = (root / "awg3_multipeer.conf").read_text()
assert multi.count("[Peer]") >= 2
assert "HeaderProtectionKey" in multi
assert "RekeyAfterTime" in multi
assert "I2 =" in multi
print("CONF_OK awg3_multipeer.conf (multi-peer + AWG3 fields)")
PY

if [[ -x "${CORE}/sing-box" ]] || command -v sing-box >/dev/null 2>&1; then
  SB="$(command -v sing-box || true)"
  [[ -x "${CORE}/sing-box" ]] && SB="${CORE}/sing-box"
  echo "note: sing-box present (${SB}); live check left manual (needs full config wrappers)"
else
  echo "note: sing-box binary not in PATH — fixture shape checks only"
fi

if [[ "${fail}" -ne 0 ]]; then
  echo "check_fixtures FAILED" >&2
  exit 1
fi
echo "check_fixtures OK"
