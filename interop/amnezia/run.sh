#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_PRIVATE_KEY:?}"
: "${BATTLE_PEER_PUBLIC_KEY:?}"
: "${BATTLE_ENDPOINT:?}"
ADDRESS="${BATTLE_ADDRESS:-10.8.0.2/32}"
JC="${BATTLE_JC:-4}"
JMIN="${BATTLE_JMIN:-40}"
JMAX="${BATTLE_JMAX:-70}"
cat > "${OUT_DIR}/amnezia.generated.conf" <<EOF
[Interface]
PrivateKey = ${BATTLE_PRIVATE_KEY}
Address = ${ADDRESS}
Jc = ${JC}
Jmin = ${JMIN}
Jmax = ${JMAX}
S1 = ${BATTLE_S1:-0}
S2 = ${BATTLE_S2:-0}
H1 = ${BATTLE_H1:-1}
H2 = ${BATTLE_H2:-2}
H3 = ${BATTLE_H3:-3}
H4 = ${BATTLE_H4:-4}

[Peer]
PublicKey = ${BATTLE_PEER_PUBLIC_KEY}
Endpoint = ${BATTLE_ENDPOINT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
echo "wrote ${OUT_DIR}/amnezia.generated.conf"
