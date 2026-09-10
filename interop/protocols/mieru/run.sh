#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_HOST:?}"
: "${BATTLE_USERNAME:?}"
: "${BATTLE_PASSWORD:?}"
export BATTLE_HOST BATTLE_USERNAME BATTLE_PASSWORD
export BATTLE_PORT="${BATTLE_PORT:-8964}"
export BATTLE_TRANSPORT="${BATTLE_TRANSPORT:-TCP}"
export BATTLE_TRAFFIC_PATTERN="${BATTLE_TRAFFIC_PATTERN:-}"
export BATTLE_MULTIPLEXING="${BATTLE_MULTIPLEXING:-}"
python3 - "${OUT_DIR}/mieru.generated.json" <<'PY'
import json, os, sys
doc = {
  "profiles": [{
    "profileName": "battle-mieru",
    "serverAddress": os.environ["BATTLE_HOST"],
    "serverPort": int(os.environ.get("BATTLE_PORT", "8964")),
    "userName": os.environ["BATTLE_USERNAME"],
    "password": os.environ["BATTLE_PASSWORD"],
    "transport": os.environ.get("BATTLE_TRANSPORT", "TCP"),
  }]
}
if os.environ.get("BATTLE_TRAFFIC_PATTERN"):
    doc["profiles"][0]["traffic_pattern"] = os.environ["BATTLE_TRAFFIC_PATTERN"]
if os.environ.get("BATTLE_MULTIPLEXING"):
    doc["profiles"][0]["multiplexing"] = os.environ["BATTLE_MULTIPLEXING"]
open(sys.argv[1], "w").write(json.dumps(doc, indent=2) + "\n")
print("wrote", sys.argv[1])
PY
