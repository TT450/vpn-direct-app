#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SING_BOX_DIR="${ROOT}/core/sing-box"
OUT_DIR="${ROOT}/harmony/entry/src/main/cpp/prebuilt/arm64-v8a"
WORK_DIR="${ROOT}/build/harmony-core"

SDK_HOME="${DEVECO_SDK_HOME:-${OHOS_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}}"
OHOS_NATIVE_HOME="${OHOS_NATIVE_HOME:-${SDK_HOME}/default/openharmony/native}"
CC_BIN="${OHOS_CC:-${OHOS_NATIVE_HOME}/llvm/bin/aarch64-unknown-linux-ohos-clang}"
CXX_BIN="${OHOS_CXX:-${OHOS_NATIVE_HOME}/llvm/bin/aarch64-unknown-linux-ohos-clang++}"
OHOS_GO="${OHOS_GO:-${HOME}/ohos-go/bin/go}"

if [[ ! -d "${SING_BOX_DIR}" ]]; then
  echo "core/sing-box is missing. Run scripts/bootstrap_core.sh first." >&2
  exit 1
fi
if [[ ! -x "${CC_BIN}" ]]; then
  echo "HarmonyOS ARM64 clang not found: ${CC_BIN}" >&2
  exit 1
fi
if [[ ! -x "${OHOS_GO}" ]]; then
  echo "OpenHarmony Go toolchain not found: ${OHOS_GO}" >&2
  echo "Use the OpenHarmony-SIG ohos_golang_go toolchain; stock Go is not accepted for the production arm64 c-shared build." >&2
  exit 1
fi

mkdir -p "${OUT_DIR}" "${WORK_DIR}"

export PATH="$(dirname "${OHOS_GO}"):${PATH}"
export GOTOOLCHAIN=local
export GOOS=openharmony
export GOARCH=arm64
export CGO_ENABLED=1
export CC="${CC_BIN}"
export CXX="${CXX_BIN}"

# The native engine must expose exactly these two C symbols. The wrapper is
# intentionally kept separate from the ArkUI/N-API bridge so the same engine
# can be tested independently before HAP packaging.
WRAPPER="${SING_BOX_DIR}/harmony/vpndirect_engine.go"
if [[ ! -f "${WRAPPER}" ]]; then
  echo "Missing ${WRAPPER}. The Harmony engine wrapper has not been implemented yet." >&2
  echo "Refusing to produce a fake libvpndirect_engine.so." >&2
  exit 2
fi

cd "${SING_BOX_DIR}"

TAGS="${VPN_DIRECT_GO_TAGS:-with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api}"
LDFLAGS="${VPN_DIRECT_GO_LDFLAGS:--s -w}"

"${OHOS_GO}" build \
  -trimpath \
  -tags "${TAGS}" \
  -buildmode=c-shared \
  -ldflags "${LDFLAGS}" \
  -o "${OUT_DIR}/libvpndirect_engine.so" \
  "${WRAPPER}"

if [[ ! -s "${OUT_DIR}/libvpndirect_engine.so" ]]; then
  echo "Core build returned without a library." >&2
  exit 3
fi

"${OHOS_NATIVE_HOME}/llvm/bin/llvm-readelf" -h "${OUT_DIR}/libvpndirect_engine.so" | grep -E 'Class:|Machine:'
"${OHOS_NATIVE_HOME}/llvm/bin/llvm-nm" -D "${OUT_DIR}/libvpndirect_engine.so" | grep -E 'vpndirect_harmony_(start|stop)' 

echo "Built ${OUT_DIR}/libvpndirect_engine.so"
