#!/usr/bin/env bash
# Release gate: refuse production claims without evidence; assert out_of_scope honesty.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

echo "== fixtures =="
"${ROOT}/scripts/prepare_core.sh" || fail=1
"${ROOT}/scripts/check_fixtures.sh" || fail=1
"${ROOT}/scripts/check_subscription_graph.sh" || fail=1
"${ROOT}/scripts/check_universal_parsers.sh" || fail=1
"${ROOT}/scripts/check_panel_compatibility.sh" || fail=1
"${ROOT}/scripts/check_matrix_sync.sh" || fail=1
"${ROOT}/scripts/check_parser_execution.sh" || fail=1
"${ROOT}/scripts/check_swift_parser_tests.sh" || fail=1

echo "== ABI / capability proofs =="
"${ROOT}/scripts/check_abi.sh" || fail=1
"${ROOT}/scripts/check_capability_proofs.sh" || fail=1

echo "== matrix honesty =="
MATRIX_JSON="${ROOT}/core/protocol-matrix.json"
MATRIX_MD="${ROOT}/docs/core/PROTOCOL_MATRIX.md"

if [[ ! -f "${MATRIX_JSON}" ]]; then
  echo "MISSING ${MATRIX_JSON}" >&2
  fail=1
else
  python3 - <<PY || fail=1
import json, pathlib
root = pathlib.Path(r"${ROOT}")
matrix = json.loads((root / "core/protocol-matrix.json").read_text())
md = (root / "docs/core/PROTOCOL_MATRIX.md").read_text()
for row in matrix.get("protocols", []):
    status = row.get("status")
    parser = row.get("parser")
    if status == "out_of_scope" and parser not in (None, "", "—", "-"):
        raise SystemExit(f"out_of_scope row claims parser={parser}: {row.get('id')}")
    if status == "tested":
        evidence = row.get("evidence") or {}
        if not evidence.get("interop") or not evidence.get("device"):
            raise SystemExit(f"tested without interop+device evidence: {row.get('id')}")
for name in ("CONNECT-UDP", "Tailscale", "OpenVPN"):
    lines = [ln for ln in md.splitlines() if name in ln and ln.strip().startswith("|") and "Protocol" not in ln]
    if not lines:
        raise SystemExit(f"matrix markdown missing row for {name}")
    if not any("out_of_scope" in ln for ln in lines):
        raise SystemExit(f"{name} row is not out_of_scope: {lines[0]}")
print("MATRIX_HONESTY_OK")
PY
fi

echo "== mieru Core registration (with_mieru required for v1.0.6+) =="
if ! grep -q "with_mieru" "${ROOT}/scripts/tags/vpn_direct_ios.tags" "${ROOT}/scripts/tags/vpn_direct_full.tags" 2>/dev/null; then
  echo "with_mieru missing from default tags (Mieru Core port incomplete)" >&2
  fail=1
else
  echo "MIERU_TAG_ON_OK"
fi
OV_SB="${ROOT}/core/overlays/sing-box"
if [[ ! -f "${OV_SB}/protocol/mieru/outbound.go" ]] || [[ ! -f "${OV_SB}/include/mieru.go" ]]; then
  echo "MISSING mieru overlay sources under core/overlays/sing-box" >&2
  fail=1
elif [[ -f "${ROOT}/scripts/apply_singbox_overlays.sh" ]] && ! bash "${ROOT}/scripts/apply_singbox_overlays.sh"; then
  echo "FAILED applying sing-box mieru overlays" >&2
  fail=1
elif [[ ! -f "${ROOT}/core/sing-box/protocol/mieru/outbound.go" ]] || [[ ! -f "${ROOT}/core/sing-box/include/mieru.go" ]]; then
  echo "MISSING mieru protocol/include after overlay apply" >&2
  fail=1
else
  echo "MIERU_PROTOCOL_PRESENT_OK"
fi
if ! grep -q "return true" "${ROOT}/core/overlays/libbox/vpndirect_mieru_register.go"; then
  echo "vpndirect_mieru_register.go must report registered" >&2
  fail=1
else
  echo "MIERU_REGISTER_FLAG_OK"
fi

"${ROOT}/scripts/check_parser_execution.sh" || fail=1

if [[ "${fail}" -ne 0 ]]; then
  echo "check_production_ready FAILED" >&2
  exit 1
fi
echo "check_production_ready OK (qualification_ready; interop/device still required for tested)"
