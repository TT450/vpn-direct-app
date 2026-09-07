#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_HOST:?}"
: "${BATTLE_PASSWORD:?}"
PORT="${BATTLE_PORT:-443}"
SNI="${BATTLE_SNI:-www.example.com}"
VARIANT="${BATTLE_VARIANT:-hysteria2}"
OBFS="${BATTLE_OBFS:-}"
OBFS_PW="${BATTLE_OBFS_PASSWORD:-}"

case "${VARIANT}" in
  hysteria|hy1)
    URI="hysteria://${BATTLE_PASSWORD}@${BATTLE_HOST}:${PORT}?sni=${SNI}#battle-hy1"
    ;;
  hysteria2|hy2|hy2-plain)
    URI="hysteria2://${BATTLE_PASSWORD}@${BATTLE_HOST}:${PORT}?sni=${SNI}&insecure=0#battle-hy2"
    ;;
  hy2-salamander)
    URI="hysteria2://${BATTLE_PASSWORD}@${BATTLE_HOST}:${PORT}?sni=${SNI}&obfs=salamander&obfs-password=${OBFS_PW:-lab-obfs}#battle-hy2-salamander"
    ;;
  hy2-gecko)
    URI="hysteria2://${BATTLE_PASSWORD}@${BATTLE_HOST}:${PORT}?sni=${SNI}&obfs=gecko&obfs-password=${OBFS_PW:-lab-obfs}#battle-hy2-gecko"
    ;;
  *)
    if [[ -n "${OBFS}" ]]; then
      URI="hysteria2://${BATTLE_PASSWORD}@${BATTLE_HOST}:${PORT}?sni=${SNI}&obfs=${OBFS}&obfs-password=${OBFS_PW}#battle-hy2"
    else
      URI="hysteria2://${BATTLE_PASSWORD}@${BATTLE_HOST}:${PORT}?sni=${SNI}#battle-hy2"
    fi
    ;;
esac
echo "${URI}" > "${OUT_DIR}/hysteria.generated.uri"
echo "wrote ${OUT_DIR}/hysteria.generated.uri"
