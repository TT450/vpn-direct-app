#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SING_BOX_DIR="${ROOT}/core/sing-box"
OUT_DIR="${ROOT}/harmony/entry/src/main/cpp/prebuilt/arm64-v8a"
SDK_HOME="${DEVECO_SDK_HOME:-${OHOS_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}}"
OHOS_NATIVE_HOME="${OHOS_NATIVE_HOME:-${SDK_HOME}/default/openharmony/native}"
CC_BIN="${OHOS_CC:-${OHOS_NATIVE_HOME}/llvm/bin/aarch64-unknown-linux-ohos-clang}"
CXX_BIN="${OHOS_CXX:-${OHOS_NATIVE_HOME}/llvm/bin/aarch64-unknown-linux-ohos-clang++}"
OHOS_GO="${OHOS_GO:-${HOME}/ohos-go/bin/go}"
WRAPPER="${ROOT}/core/harmony/vpndirect_engine.go"
BUILD_DIR="${SING_BOX_DIR}/.vpndirect-harmony-build"

[[ -d "${SING_BOX_DIR}" ]] || { echo "core/sing-box is missing; run scripts/bootstrap_core.sh first." >&2; exit 1; }
[[ -x "${CC_BIN}" ]] || { echo "HarmonyOS ARM64 clang not found: ${CC_BIN}" >&2; exit 1; }
[[ -x "${OHOS_GO}" ]] || { echo "OpenHarmony Go toolchain not found: ${OHOS_GO}" >&2; exit 1; }
[[ -f "${WRAPPER}" ]] || { echo "Missing ${WRAPPER}" >&2; exit 1; }

mkdir -p "${OUT_DIR}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cp "${WRAPPER}" "${BUILD_DIR}/main.go"

export PATH="$(dirname "${OHOS_GO}"):${PATH}"
export GOTOOLCHAIN=local
export GOOS=openharmony
export GOARCH=arm64
export CGO_ENABLED=1
export CC="${CC_BIN}"
export CXX="${CXX_BIN}"

cd "${SING_BOX_DIR}"
# Matches core/VERSION. with_lx_command is required by the current
# experimental/libbox PlatformInterface and with_mieru is part of the pinned
# mobile feature set.
TAGS="${VPN_DIRECT_GO_TAGS:-with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_naive_outbound,with_clash_api,with_xhttp,with_awg,with_lx_idle_suspend,with_lx_command,with_mieru,with_openvpn,with_openconnect,with_tailscale,with_shadowsocksr}"
LDFLAGS="${VPN_DIRECT_GO_LDFLAGS:--s -w -checklinkname=0}"

cleanup() { rm -rf "${BUILD_DIR}"; }
trap cleanup EXIT

"${OHOS_GO}" build \
  -trimpath \
  -tags "${TAGS}" \
  -buildmode=c-shared \
  -ldflags "${LDFLAGS}" \
  -o "${OUT_DIR}/libvpndirect_engine.so" \
  "./.vpndirect-harmony-build"

[[ -s "${OUT_DIR}/libvpndirect_engine.so" ]] || { echo "Core build produced no library." >&2; exit 3; }

"${OHOS_NATIVE_HOME}/llvm/bin/llvm-readelf" -h "${OUT_DIR}/libvpndirect_engine.so" | grep -E 'Class:|Machine:'
"${OHOS_NATIVE_HOME}/llvm/bin/llvm-nm" -D "${OUT_DIR}/libvpndirect_engine.so" | grep -E 'vpndirect_harmony_(start|stop)'
echo "Built ${OUT_DIR}/libvpndirect_engine.so"
