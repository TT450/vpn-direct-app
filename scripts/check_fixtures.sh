#!/usr/bin/env bash
# Validate regression fixtures (shape + optional sing-box check).
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
require_file "${FIX}/masque_cloudflare.json"
require_file "${FIX}/xray_vless_xhttp.json"

# Basic JSON parse
python3 - <<'PY' || fail=1
import json, pathlib, sys
root = pathlib.Path("/Users/elshan/Direct VPN Client/tests/fixtures/regression")
for name in ("masque_cloudflare.json", "xray_vless_xhttp.json"):
    json.loads((root / name).read_text())
    print("JSON_OK", name)
# URI schemes
for name in ("vless_ws_reality.uri", "vless_xhttp.uri", "vless_encryption_pq.uri"):
    text = (root / name).read_text().strip()
    assert text.startswith("vless://"), name
    print("URI_OK", name)
# AWG conf sections
conf = (root / "awg2_sample.conf").read_text()
assert "[Interface]" in conf and "[Peer]" in conf and "Jc =" in conf
print("CONF_OK awg2_sample.conf")
PY

# Optional: sing-box check when binary/tools available
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
