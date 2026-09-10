#!/usr/bin/env bash
# Structural asserts for TheTochka Compatibility Harvest P0 fixtures.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="${ROOT}/tests/fixtures/regression"
fail=0

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "MISSING $1" >&2
    fail=1
  else
    echo "OK $1"
  fi
}

require_file "${FIX}/remnawave_country_multi_leaf.json"
require_file "${FIX}/remnawave_auto_and_country_same_backend.json"
require_file "${FIX}/remnawave_cascade_dialerproxy.json"
require_file "${FIX}/hy2_share.uri"
require_file "${FIX}/hysteria_share.uri"
require_file "${FIX}/panel_stub_rejected.uri"

python3 - <<PY || fail=1
import json, pathlib

root = pathlib.Path(r"${FIX}")

multi = json.loads((root / "remnawave_country_multi_leaf.json").read_text())
assert len(multi) == 1
outs = multi[0]["outbounds"]
protos = {o["protocol"].lower() for o in outs}
assert "vless" in protos and "hysteria2" in protos
assert multi[0]["routing"]["balancers"]
print("GRAPH_FIXTURE_OK country multi-leaf VLESS+HY2 + balancer")

both = json.loads((root / "remnawave_auto_and_country_same_backend.json").read_text())
assert len(both) == 2
hosts = []
for profile in both:
    for o in profile["outbounds"]:
        vnext = o["settings"]["vnext"][0]
        hosts.append(f"{vnext['address']}:{vnext['port']}")
assert hosts[0] == hosts[1] == "1.2.3.4:443"
names = [p["remarks"] for p in both]
assert any("автовыбор" in n.lower() or "auto" in n.lower() for n in names)
assert any("germany" in n.lower() for n in names)
print("GRAPH_FIXTURE_OK auto+country same backend (per-profile dedupe regression)")

cascade = json.loads((root / "remnawave_cascade_dialerproxy.json").read_text())
assert any(
    ((o.get("streamSettings") or {}).get("sockopt") or {}).get("dialerProxy")
    for o in cascade[0]["outbounds"]
)
print("GRAPH_FIXTURE_OK cascade dialerProxy present")

hy2 = (root / "hy2_share.uri").read_text().strip().lower()
assert hy2.startswith("hy2://") or hy2.startswith("hysteria2://")
print("URI_OK hy2_share.uri")

hy1 = (root / "hysteria_share.uri").read_text().strip().lower()
assert hy1.startswith("hysteria://")
print("URI_OK hysteria_share.uri")

stub = (root / "panel_stub_rejected.uri").read_text().strip().lower()
assert "@127.0.0.1:1" in stub or "00000000-0000-0000-0000-000000000000" in stub
print("URI_OK panel_stub_rejected.uri")
PY

if [[ "${fail}" -ne 0 ]]; then
  echo "check_subscription_graph FAILED" >&2
  exit 1
fi
echo "check_subscription_graph OK"
