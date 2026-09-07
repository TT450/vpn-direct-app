#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_PRIVATE_KEY:?}"
: "${BATTLE_PEER_PUBLIC_KEY:?}"
: "${BATTLE_ENDPOINT:?}"
ADDRESS="${BATTLE_ADDRESS:-10.8.0.2/32}"
VER="${BATTLE_AWG_VERSION:-2}"
cat > "${OUT_DIR}/amneziawg.generated.conf" <<EOF
[Interface]
PrivateKey = ${BATTLE_PRIVATE_KEY}
Address = ${ADDRESS}
Jc = ${BATTLE_JC:-4}
Jmin = ${BATTLE_JMIN:-40}
Jmax = ${BATTLE_JMAX:-70}
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
# Hint version for WireGuardConfAdapter
echo "# amnezia_version=${VER}" >> "${OUT_DIR}/amneziawg.generated.conf"
echo "wrote ${OUT_DIR}/amneziawg.generated.conf (AWG ${VER})"
