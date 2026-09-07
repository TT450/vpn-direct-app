#!/usr/bin/env bash
# Panel compatibility honesty: claimed fixtures/evidence must exist.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JSON="${ROOT}/core/panel-compatibility.json"
fail=0

if [[ ! -f "${JSON}" ]]; then
  echo "MISSING ${JSON}" >&2
  exit 1
fi

python3 - <<PY || fail=1
import json, pathlib
root = pathlib.Path(r"${ROOT}")
doc = json.loads((root / "core/panel-compatibility.json").read_text())
for panel in doc.get("panels", []):
    name = panel.get("panel")
    status = panel.get("status")
    evidence = panel.get("evidence") or {}
    dossier = panel.get("dossier")
    if dossier and not (root / dossier).is_file():
        raise SystemExit(f"missing dossier for {name}: {dossier}")
    if evidence.get("fixtures"):
        fx = root / "tests/fixtures/panels" / name
        # 3x-ui folder uses 3x-ui; panel id matches
        if name == "3x-ui":
            fx = root / "tests/fixtures/panels/3x-ui"
        if not fx.is_dir():
            raise SystemExit(f"panel {name} claims fixtures but missing {fx}")
        if not any(fx.iterdir()):
            raise SystemExit(f"panel {name} fixtures dir empty")
    if status in ("implemented", "tested", "fixture_pass") and not evidence.get("fixtures"):
        raise SystemExit(f"panel {name} status={status} without fixtures evidence")
    if status == "tested" and not (evidence.get("interop") and evidence.get("device")):
        raise SystemExit(f"panel {name} tested without interop+device evidence")
print("PANEL_COMPATIBILITY_OK")
PY

if [[ "${fail}" -ne 0 ]]; then
  echo "check_panel_compatibility FAILED" >&2
  exit 1
fi
echo "check_panel_compatibility OK"
