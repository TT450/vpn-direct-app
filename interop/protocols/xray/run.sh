#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_HOST:?set BATTLE_HOST}"
: "${BATTLE_UUID:?set BATTLE_UUID}"
PORT="${BATTLE_PORT:-443}"
SNI="${BATTLE_SNI:-www.example.com}"
PBK="${BATTLE_PBK:-}"
SID="${BATTLE_SID:-}"
PATH_WS="${BATTLE_PATH:-/}"
VARIANT="${BATTLE_VARIANT:-vless-reality-ws}"

case "${VARIANT}" in
  vless-tcp)
    URI="vless://${BATTLE_UUID}@${BATTLE_HOST}:${PORT}?encryption=none&security=none&type=tcp#battle-vless-tcp"
    ;;
  vless-tls)
    URI="vless://${BATTLE_UUID}@${BATTLE_HOST}:${PORT}?encryption=none&security=tls&sni=${SNI}&type=tcp#battle-vless-tls"
    ;;
  vless-reality|vless-reality-tcp)
    URI="vless://${BATTLE_UUID}@${BATTLE_HOST}:${PORT}?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PBK}&sid=${SID}&type=tcp#battle-vless-reality"
    ;;
  vless-vision)
    URI="vless://${BATTLE_UUID}@${BATTLE_HOST}:${PORT}?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PBK}&sid=${SID}&type=tcp&flow=xtls-rprx-vision#battle-vless-vision"
    ;;
  vless-ws|vless-reality-ws)
    URI="vless://${BATTLE_UUID}@${BATTLE_HOST}:${PORT}?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PBK}&sid=${SID}&type=ws&path=${PATH_WS}#battle-vless-ws"
    ;;
  vless-grpc)
    URI="vless://${BATTLE_UUID}@${BATTLE_HOST}:${PORT}?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PBK}&sid=${SID}&type=grpc&serviceName=gun#battle-vless-grpc"
    ;;
  vless-httpupgrade)
    URI="vless://${BATTLE_UUID}@${BATTLE_HOST}:${PORT}?encryption=none&security=tls&sni=${SNI}&type=httpupgrade&path=${PATH_WS}#battle-vless-httpupgrade"
    ;;
  vless-xhttp)
    URI="vless://${BATTLE_UUID}@${BATTLE_HOST}:${PORT}?encryption=none&security=tls&sni=${SNI}&type=xhttp&path=${PATH_WS}#battle-vless-xhttp"
    ;;
  vless-xhttp-reality)
    URI="vless://${BATTLE_UUID}@${BATTLE_HOST}:${PORT}?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PBK}&sid=${SID}&type=xhttp&path=${PATH_WS}#battle-vless-xhttp-reality"
    ;;
  vmess)
    URI="$(
      BATTLE_HOST="${BATTLE_HOST}" BATTLE_PORT="${PORT}" BATTLE_UUID="${BATTLE_UUID}" BATTLE_SNI="${SNI}" python3 - <<'PY'
import base64, json, os
doc = {
  "v": "2", "ps": "battle-vmess", "add": os.environ["BATTLE_HOST"],
  "port": str(os.environ.get("BATTLE_PORT", "443")), "id": os.environ["BATTLE_UUID"],
  "aid": "0", "net": "ws", "type": "none", "host": "", "path": "/",
  "tls": "tls", "sni": os.environ.get("BATTLE_SNI", "www.example.com"),
}
print("vmess://" + base64.b64encode(json.dumps(doc, separators=(",", ":")).encode()).decode())
PY
    )"
    ;;
  trojan)
    : "${BATTLE_PASSWORD:?}"
    URI="trojan://${BATTLE_PASSWORD}@${BATTLE_HOST}:${PORT}?security=tls&sni=${SNI}&type=tcp#battle-trojan"
    ;;
  ss|shadowsocks)
    : "${BATTLE_PASSWORD:?}"
    USERINFO="$(printf '%s' "aes-256-gcm:${BATTLE_PASSWORD}" | base64 | tr -d '\n')"
    URI="ss://${USERINFO}@${BATTLE_HOST}:${PORT}#battle-ss"
    ;;
  *)
    echo "unknown BATTLE_VARIANT=${VARIANT}" >&2
    exit 2
    ;;
esac

echo "${URI}" > "${OUT_DIR}/xray.generated.uri"
echo "wrote ${OUT_DIR}/xray.generated.uri (${VARIANT})"
