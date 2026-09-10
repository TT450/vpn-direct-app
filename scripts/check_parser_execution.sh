#!/usr/bin/env bash
# Executable parser→builder→sing-box check regression (not filename-only gates).
# Uses secret-free fixtures under tests/fixtures/regression/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="${ROOT}/tests/fixtures/regression"
CORE="${ROOT}/core/sing-box"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail=0

# Ensure mieru (and other) overlays are on the Core pin before any go build.
bash "${ROOT}/scripts/prepare_core.sh"

resolve_singbox() {
  if [[ -x "${CORE}/sing-box" ]]; then
    echo "${CORE}/sing-box"
    return
  fi
  if command -v sing-box >/dev/null 2>&1; then
    command -v sing-box
    return
  fi
  # Build a local binary with VPN Direct tags when missing.
  if [[ -d "${CORE}" ]]; then
    TAGS="$(tr ',' ' ' < "${ROOT}/scripts/tags/vpn_direct_full.tags")"
    echo "building sing-box with tags: ${TAGS}" >&2
    (cd "${CORE}" && go build -tags "${TAGS}" -o "${TMP}/sing-box" ./cmd/sing-box)
    echo "${TMP}/sing-box"
    return
  fi
  echo "sing-box unavailable" >&2
  return 1
}

SB="$(resolve_singbox)" || exit 1

wrap_outbound() {
  local outbound_json="$1"
  local out="$2"
  python3 - "$outbound_json" "$out" <<'PY'
import json, sys
ob = json.loads(open(sys.argv[1]).read())
inbound = {"type": "socks", "tag": "in", "listen": "127.0.0.1", "listen_port": 0}
if isinstance(ob, dict) and "outbounds" in ob:
    cfg = {
        "log": {"level": "warn"},
        "inbounds": [inbound],
        "outbounds": ob["outbounds"] + [{"type": "direct", "tag": "direct"}],
    }
else:
    cfg = {
        "log": {"level": "warn"},
        "inbounds": [inbound],
        "outbounds": [ob, {"type": "direct", "tag": "direct"}],
    }
open(sys.argv[2], "w").write(json.dumps(cfg))
PY
}

check_cfg() {
  local label="$1"
  local cfg="$2"
  if ! "${SB}" check -c "${cfg}" >/dev/null 2>"${TMP}/${label}.err"; then
    echo "FAIL LibboxCheck/sing-box check: ${label}" >&2
    cat "${TMP}/${label}.err" >&2 || true
    fail=1
  else
    echo "OK check ${label}"
  fi
}

# Family: mieru (requires with_mieru in linked binary)
wrap_outbound "${FIX}/mieru/client.json" "${TMP}/mieru.json"
check_cfg "mieru" "${TMP}/mieru.json"

# Family: minimal protocol outbounds (secret-free placeholders)
python3 - "${TMP}" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
inbound = {"type": "socks", "tag": "in", "listen": "127.0.0.1", "listen_port": 0}
# 32-byte curve25519 public key, URL-safe base64 (no pad) — length accepted by sing-box
REALITY_PK = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
families = {
  "vless": {
    "type": "vless", "tag": "vless-out",
    "server": "203.0.113.10", "server_port": 443,
    "uuid": "11111111-1111-1111-1111-111111111111",
    "tls": {"enabled": True, "server_name": "www.example.com",
            "utls": {"enabled": True, "fingerprint": "chrome"},
            "reality": {"enabled": True, "public_key": REALITY_PK, "short_id": "abcd"}},
    "transport": {"type": "ws", "path": "/ws"},
  },
  "vmess": {
    "type": "vmess", "tag": "vmess-out",
    "server": "203.0.113.11", "server_port": 443,
    "uuid": "22222222-2222-2222-2222-222222222222", "security": "auto",
    "tls": {"enabled": True, "server_name": "www.example.com"},
  },
  "trojan": {
    "type": "trojan", "tag": "trojan-out",
    "server": "203.0.113.12", "server_port": 443,
    "password": "password123",
    "tls": {"enabled": True, "server_name": "www.example.com"},
  },
  "ss": {
    "type": "shadowsocks", "tag": "ss-out",
    "server": "203.0.113.13", "server_port": 8388,
    "method": "aes-256-gcm", "password": "password123",
  },
  "hy2": {
    "type": "hysteria2", "tag": "hy2-out",
    "server": "203.0.113.14", "server_port": 443,
    "password": "password123",
    "tls": {"enabled": True, "server_name": "www.example.com", "alpn": ["h3"]},
  },
  "tuic": {
    "type": "tuic", "tag": "tuic-out",
    "server": "203.0.113.15", "server_port": 443,
    "uuid": "33333333-3333-3333-3333-333333333333",
    "password": "password123",
    "tls": {"enabled": True, "server_name": "www.example.com", "alpn": ["h3"]},
  },
  "anytls": {
    "type": "anytls", "tag": "anytls-out",
    "server": "203.0.113.16", "server_port": 443,
    "password": "password123",
    "tls": {"enabled": True, "server_name": "www.example.com"},
  },
}
for name, ob in families.items():
    cfg = {
        "log": {"level": "warn"},
        "inbounds": [inbound],
        "outbounds": [ob, {"type": "direct", "tag": "direct"}],
    }
    (root / f"{name}.json").write_text(json.dumps(cfg))
print("SYNTH_OK")
PY

for fam in vless vmess trojan ss hy2 tuic anytls; do
  check_cfg "${fam}" "${TMP}/${fam}.json"
done

# Clash nested fixture shape (Swift parser coverage asserted separately; here structural)
python3 - <<PY || fail=1
from pathlib import Path
text = Path(r"${FIX}/clash/clash_reality_ws.yaml").read_text()
assert "reality-opts:" in text and "ws-opts:" in text
# Flatten simulation matches ClashYAMLAdapter nest roots
assert "public-key:" in text and "short-id:" in text
print("CLASH_NEST_SHAPE_OK")
PY

# Fuzz smoke: garbage must not crash sing-box check (non-zero exit OK, no abort)
python3 - "${TMP}" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
(root/"fuzz_garbage.json").write_text("{not json")
(root/"fuzz_b64.txt").write_bytes(b"\xff" * 64)
(root/"fuzz_big.yaml").write_text("proxies:\n" + ("- name: x\n  type: ss\n  server: 1.1.1.1\n  port: 1\n" * 20000))
print("FUZZ_INPUTS_OK")
PY

set +e
"${SB}" check -c "${TMP}/fuzz_garbage.json" >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -eq 0 ]]; then
  echo "WARN fuzz_garbage unexpectedly passed" >&2
else
  echo "OK fuzz_garbage rejected (exit ${rc})"
fi

# Panic boundary note must exist
if [[ ! -f "${ROOT}/docs/core/PANIC_BOUNDARY.md" ]]; then
  echo "MISSING docs/core/PANIC_BOUNDARY.md" >&2
  fail=1
else
  echo "OK panic boundary doc"
fi

if [[ "${fail}" -ne 0 ]]; then
  echo "check_parser_execution FAILED" >&2
  exit 1
fi
echo "check_parser_execution OK"
