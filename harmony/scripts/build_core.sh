#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT}/.." && pwd)"
VERSION_FILE="${REPO_ROOT}/core/VERSION"
CORE="${REPO_ROOT}/core/sing-box"
ADAPTER="${ROOT}/core/vpndirect_engine/main.go"
WORK="${REPO_ROOT}/.build/harmony-core"
OUT_DIR="${ROOT}/entry/src/main/libs/arm64-v8a"
OUT="${OUT_DIR}/libvpndirect_engine.so"

DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}"
OHOS_NATIVE_HOME="${OHOS_NATIVE_HOME:-${DEVECO_SDK_HOME}/default/openharmony/native}"
CC_BIN="${CC_BIN:-${OHOS_NATIVE_HOME}/llvm/bin/aarch64-unknown-linux-ohos-clang}"
CXX_BIN="${CXX_BIN:-${OHOS_NATIVE_HOME}/llvm/bin/aarch64-unknown-linux-ohos-clang++}"
OHOS_GO_FORK="${OHOS_GO_FORK:-${HOME}/ohos-build/ohos_golang_go}"

[[ -f "${VERSION_FILE}" ]] || { echo "error: missing ${VERSION_FILE}" >&2; exit 1; }
[[ -f "${ADAPTER}" ]] || { echo "error: missing ${ADAPTER}" >&2; exit 1; }
[[ -d "${CORE}/.git" ]] || { echo "error: ${CORE} is not initialized; run scripts/bootstrap_core.sh first" >&2; exit 1; }

# shellcheck disable=SC1090
source "${VERSION_FILE}"
[[ "${CORE_VERSION}" == "0.1.0" ]] || { echo "error: unexpected CORE_VERSION=${CORE_VERSION}" >&2; exit 1; }
[[ "${SING_BOX_REV}" == "v1.14.0-lx.35" ]] || { echo "error: refusing non-pinned sing-box ${SING_BOX_REV}" >&2; exit 1; }
[[ "${UPSTREAM_VERSION}" == "1.14.0" ]] || { echo "error: unexpected UPSTREAM_VERSION=${UPSTREAM_VERSION}" >&2; exit 1; }
[[ "${GO_VERSION}" == "go1.26.6" ]] || { echo "error: unexpected Go pin ${GO_VERSION}" >&2; exit 1; }

[[ -x "${OHOS_GO_FORK}/bin/go" ]] || {
  echo "error: OpenHarmony Go fork not found: ${OHOS_GO_FORK}/bin/go" >&2
  echo "Set OHOS_GO_FORK to the OHOS Go fork that supports ${GO_VERSION}." >&2
  exit 2
}
[[ -x "${CC_BIN}" ]] || { echo "error: missing OHOS clang: ${CC_BIN}" >&2; exit 2; }
[[ -x "${CXX_BIN}" ]] || { echo "error: missing OHOS clang++: ${CXX_BIN}" >&2; exit 2; }

export PATH="${OHOS_GO_FORK}/bin:${PATH}"
export GOTOOLCHAIN=local
export CGO_ENABLED=1
export GOOS=openharmony
export GOARCH=arm64
export CC="${CC_BIN}"
export CXX="${CXX_BIN}"
export CGO_CFLAGS="${CGO_CFLAGS:-} -ftls-model=global-dynamic"

CURRENT_GO="$(go env GOVERSION)"
[[ "${CURRENT_GO}" == "${GO_VERSION}" ]] || {
  echo "error: OpenHarmony Go toolchain is ${CURRENT_GO}, expected ${GO_VERSION}" >&2
  exit 2
}

cd "${REPO_ROOT}"
bash scripts/prepare_core.sh --reset

BUILD_TAGS="$(echo "${BUILD_TAGS}" | tr ',' ' ')"
rm -rf "${WORK}"
mkdir -p "${WORK}/cmd/vpndirect_harmony" "${OUT_DIR}"
cp "${ADAPTER}" "${WORK}/cmd/vpndirect_harmony/main.go"

cd "${WORK}/cmd/vpndirect_harmony"
cat > go.mod <<EOF
module vpndirect-harmony-build

go 1.26.6

require github.com/sagernet/sing-box v1.14.0
EOF
go mod edit -replace "github.com/sagernet/sing-box=${CORE}"
go mod tidy

LDFLAGS="-s -w -checklinkname=0 -linkmode external -extldflags=-Wl,-z,lazy,-soname,libvpndirect_engine.so"
LDFLAGS="${LDFLAGS} -X github.com/sagernet/sing-box/experimental/libbox.vpnDirectCoreVersionOverride=${CORE_VERSION}"
rm -f "${OUT}"

go build -trimpath -tags "${BUILD_TAGS}" -ldflags "${LDFLAGS}" -buildmode=c-shared -o "${OUT}" .

llvm-readelf -d "${OUT}" | grep -q 'SONAME.*libvpndirect_engine.so' || { echo "error: missing SONAME" >&2; exit 1; }
llvm-readelf -h "${OUT}" | grep -q 'AArch64' || { echo "error: not ARM64/AArch64" >&2; exit 1; }
nm -D "${OUT}" | grep -q 'vpndirect_harmony_start' || { echo "error: start export missing" >&2; exit 1; }
nm -D "${OUT}" | grep -q 'vpndirect_harmony_stop' || { echo "error: stop export missing" >&2; exit 1; }

cat > "${OUT_DIR}/libvpndirect_engine.version" <<EOF
CORE_NAME=${CORE_NAME}
CORE_VERSION=${CORE_VERSION}
SING_BOX_REV=${SING_BOX_REV}
UPSTREAM_VERSION=${UPSTREAM_VERSION}
GO_VERSION=${GO_VERSION}
BUILD_TAGS=${BUILD_TAGS}
GOOS=${GOOS}
GOARCH=${GOARCH}
EOF

echo "OK: ${OUT}"
echo "Pinned Core: ${CORE_NAME} ${CORE_VERSION} / sing-box ${SING_BOX_REV} / ${GO_VERSION}"
