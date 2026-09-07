#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
if [[ -z "${WARP_PRIVATE_KEY:-}" ]]; then
  echo "WARP_* unset — writing placeholder JSON for parser shape only" >&2
  cat > "${OUT_DIR}/masque.generated.json" <<'EOF'
{
  "type": "masque",
  "server": "203.0.113.90",
  "server_port": 443,
  "note": "replace with WARP env identity before live connect"
}
EOF
else
  cat > "${OUT_DIR}/masque.generated.json" <<EOF
{
  "type": "masque",
  "private_key": "${WARP_PRIVATE_KEY}",
  "peer_public_key": "${WARP_PEER_PUBLIC_KEY}",
  "endpoint": "${WARP_ENDPOINT}",
  "address": "${WARP_ADDRESS}",
  "server": "${BATTLE_HOST:-203.0.113.90}",
  "server_port": ${BATTLE_PORT:-443}
}
EOF
fi
echo "wrote ${OUT_DIR}/masque.generated.json"
