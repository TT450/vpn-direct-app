#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_HOST:?}"
PORT="${BATTLE_PORT:-22}"
USER="${BATTLE_USERNAME:-lab}"
PASS="${BATTLE_PASSWORD:-lab-ssh-password}"
URI="ssh://${USER}:${PASS}@${BATTLE_HOST}:${PORT}#battle-ssh"
echo "${URI}" > "${OUT_DIR}/ssh.generated.uri"
# Optional key-based note file (do not commit private keys)
cat > "${OUT_DIR}/ssh.generated.notes.txt" <<EOF
password URI written; for key auth set private_key path in app / attributes only on lab machine
host=${BATTLE_HOST} port=${PORT} user=${USER}
EOF
echo "wrote ${OUT_DIR}/ssh.generated.uri"
