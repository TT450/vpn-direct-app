#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HARMONY="${ROOT}/harmony"
ENGINE="${HARMONY}/entry/src/main/cpp/prebuilt/arm64-v8a/libvpndirect_engine.so"

fail() { echo "RELEASE GATE: FAIL — $1" >&2; exit 1; }
pass() { echo "RELEASE GATE: PASS — $1"; }

[[ -f "${HARMONY}/entry/src/main/module.json5" ]] || fail "entry module manifest missing"
[[ -f "${HARMONY}/entry/build-profile.json5" ]] || fail "entry build profile missing"
[[ -f "${HARMONY}/entry/src/main/cpp/CMakeLists.txt" ]] || fail "CMakeLists missing"
[[ -f "${HARMONY}/entry/src/main/cpp/napi_init.cpp" ]] || fail "N-API bridge missing"
[[ -f "${ROOT}/core/harmony/vpndirect_engine.go" ]] || fail "Harmony core wrapper missing"
[[ -f "${ROOT}/scripts/build_harmony_core.sh" ]] || fail "Harmony core build script missing"
pass "source/build contracts exist"

python3 - "${HARMONY}/entry/src/main/module.json5" <<'PY'
import json, sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
for token in ('ohos.permission.INTERNET', 'ohos.permission.MANAGE_VPN', '"type": "vpn"', 'VpnDirectVpnExtension'):
    if token not in text:
        raise SystemExit(f'missing manifest contract: {token}')
PY
pass "VPN extension and permissions are declared"

if [[ ! -s "${ENGINE}" ]]; then
  fail "libvpndirect_engine.so is missing; run scripts/build_harmony_core.sh on a DevEco/OpenHarmony ARM64 host"
fi

if command -v file >/dev/null 2>&1; then
  file "${ENGINE}" | grep -Eq 'ELF 64-bit.*ARM aarch64' || fail "engine is not an AArch64 ELF64 binary"
fi

if command -v llvm-nm >/dev/null 2>&1; then
  llvm-nm -D "${ENGINE}" | grep -q 'vpndirect_harmony_start' || fail "engine start symbol missing"
  llvm-nm -D "${ENGINE}" | grep -q 'vpndirect_harmony_stop' || fail "engine stop symbol missing"
fi
pass "native engine exists and exports the VPN entry points"

if [[ "${RUN_HVIGOR_BUILD:-0}" == "1" ]]; then
  command -v hvigor >/dev/null 2>&1 || fail "RUN_HVIGOR_BUILD=1 but hvigor is not installed"
  (cd "${HARMONY}" && hvigor --mode module -p module=entry@default assembleHap)
  find "${HARMONY}" -type f -name '*.hap' -size +0c -print -quit | grep -q . || fail "hvigor completed but no HAP was produced"
  pass "HAP build completed"
else
  echo "RELEASE GATE: SKIP — HAP build (set RUN_HVIGOR_BUILD=1 on a configured DevEco host)"
fi

pass "release gate completed"
