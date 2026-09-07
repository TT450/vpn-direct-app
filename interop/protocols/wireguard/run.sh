#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_PRIVATE_KEY:?}"
: "${BATTLE_PEER_PUBLIC_KEY:?}"
: "${BATTLE_ENDPOINT:?}"
ADDRESS="${BATTLE_ADDRESS:-10.8.0.2/32}"
DNS="${BATTLE_DNS:-1.1.1.1}"
MTU="${BATTLE_MTU:-1280}"
KA="${BATTLE_KEEPALIVE:-25}"
PSK_LINE=""
if [[ -n "${BATTLE_PSK:-}" ]]; then
  PSK_LINE="PresharedKey = ${BATTLE_PSK}"
fi
cat > "${OUT_DIR}/wireguard.generated.conf" <<EOF
[Interface]
PrivateKey = ${BATTLE_PRIVATE_KEY}
Address = ${ADDRESS}
DNS = ${DNS}
MTU = ${MTU}

[Peer]
PublicKey = ${BATTLE_PEER_PUBLIC_KEY}
${PSK_LINE}
Endpoint = ${BATTLE_ENDPOINT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = ${KA}
EOF
echo "wrote ${OUT_DIR}/wireguard.generated.conf"
