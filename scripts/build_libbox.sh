#!/usr/bin/env bash
# Build VPN Direct Libbox.xcframework from core/sing-box (sing-box-lx).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${ROOT}/core/sing-box"
OUT_FRAMEWORK="${ROOT}/Libbox.xcframework"
VERSION_FILE="${ROOT}/core/VERSION"

# shellcheck disable=SC1090
if [[ -f "${VERSION_FILE}" ]]; then
  # Export KEY=VAL lines (ignore comments / blanks)
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
    if [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      export "${line?}"
    fi
  done < "${VERSION_FILE}"
fi

BUILD_TAGS="${BUILD_TAGS:-with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_naive_outbound,with_clash_api,with_xhttp,with_awg,with_lx_idle_suspend}"
CORE_VERSION="${CORE_VERSION:-0.1.0}"

if [[ ! -d "${CORE}" ]]; then
  echo "error: missing ${CORE}" >&2
  echo "Run: git submodule update --init --recursive" >&2
  echo "Or:  ./scripts/bootstrap_core.sh" >&2
  exit 1
fi

if [[ ! -f "${CORE}/cmd/internal/build_libbox/main.go" ]] && [[ ! -d "${CORE}/cmd/internal/build_libbox" ]]; then
  echo "error: build_libbox not found under ${CORE}" >&2
  exit 1
fi

command -v go >/dev/null || { echo "error: go not installed" >&2; exit 1; }

# Prefer pinned Go from sing-box-lx when available
if [[ -f "${CORE}/go.version" ]]; then
  PINNED="$(tr -d ' \n' < "${CORE}/go.version")"
  echo "note: donor pins Go ${PINNED}; current $(go version)"
fi

export PATH="${PATH}:$(go env GOPATH)/bin"
if ! command -v gomobile >/dev/null; then
  echo "installing gomobile…"
  go install golang.org/x/mobile/cmd/gomobile@latest
  go install golang.org/x/mobile/cmd/gobind@latest
  gomobile init || true
fi

echo "=== VPN Direct Libbox build ==="
echo "core:    ${CORE}"
echo "tags:    ${BUILD_TAGS}"
echo "version: ${CORE_VERSION}"
echo "out:     ${OUT_FRAMEWORK}"

cd "${CORE}"

# Apply tracked VPN Direct overlays (capability export) into libbox package
OVERLAY_DIR="${ROOT}/core/overlays/libbox"
if [[ -d "${OVERLAY_DIR}" ]]; then
  echo "applying overlays from ${OVERLAY_DIR}"
  cp -f "${OVERLAY_DIR}"/*.go "${CORE}/experimental/libbox/"
fi

# Ensure AWG submodule present when with_awg is requested
if [[ "${BUILD_TAGS}" == *with_awg* ]]; then
  git submodule update --init --recursive || true
fi

# build_libbox reads tags from env in some sing-box versions; pass via EXTRA
# Common interface: go run ./cmd/internal/build_libbox -target apple
export LIBBOX_BUILD_TAGS="${BUILD_TAGS}"
export VPN_DIRECT_CORE_VERSION="${CORE_VERSION}"

# Prefer lean Apple bind target for NE (faster); full set via VPN_DIRECT_APPLE_PLATFORM
APPLE_PLATFORM="${VPN_DIRECT_APPLE_PLATFORM:-ios,iossimulator,macos,tvos}"

# Try lx-aware tags file if present
if [[ -f "${ROOT}/scripts/vpn_direct_ios.tags" ]]; then
  BUILD_TAGS="$(tr -d ' \n' < "${ROOT}/scripts/vpn_direct_ios.tags")"
  export LIBBOX_BUILD_TAGS="${BUILD_TAGS}"
fi

echo "running build_libbox (platform=${APPLE_PLATFORM})…"
# Remove previous output inside core if any
rm -rf "${CORE}/Libbox.xcframework" "${ROOT}/Libbox.xcframework.build"

set +e
go run ./cmd/internal/build_libbox -target apple -platform "${APPLE_PLATFORM}" "$@"
STATUS=$?
set -e

if [[ ${STATUS} -ne 0 ]]; then
  echo "build_libbox failed with ${STATUS}; retrying without -platform…"
  go run ./cmd/internal/build_libbox -target apple "$@" || {
    echo "error: build_libbox failed" >&2
    exit 1
  }
fi

# Locate produced framework
CANDIDATE=""
for p in \
  "${CORE}/Libbox.xcframework" \
  "${CORE}/bind/Libbox.xcframework" \
  "${ROOT}/Libbox.xcframework"
do
  if [[ -d "${p}" ]]; then
    CANDIDATE="${p}"
    break
  fi
done

if [[ -z "${CANDIDATE}" ]]; then
  echo "error: Libbox.xcframework not found after build" >&2
  find "${CORE}" -maxdepth 3 -name 'Libbox.xcframework' -type d 2>/dev/null || true
  exit 1
fi

if [[ "${CANDIDATE}" != "${OUT_FRAMEWORK}" ]]; then
  rm -rf "${OUT_FRAMEWORK}"
  cp -R "${CANDIDATE}" "${OUT_FRAMEWORK}"
fi

# Stamp a sidecar version file for the app
cat > "${ROOT}/Libbox.xcframework/VPNDirectCore.version" <<EOF
CORE_NAME=${CORE_NAME:-VPNDirectCore}
CORE_VERSION=${CORE_VERSION}
BUILD_TAGS=${BUILD_TAGS}
BUILT_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GO=$(go version)
SING_BOX_REV=${SING_BOX_REV:-unknown}
EOF

echo "OK: ${OUT_FRAMEWORK}"
