#!/usr/bin/env bash
# Build VPN Direct Libbox.xcframework from core/sing-box (sing-box-lx).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${ROOT}/core/sing-box"
OUT_FRAMEWORK="${ROOT}/Libbox.xcframework"
VERSION_FILE="${ROOT}/core/VERSION"

# shellcheck disable=SC1090
if [[ -f "${VERSION_FILE}" ]]; then
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
    if [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      export "${line?}"
    fi
  done < "${VERSION_FILE}"
fi

BUILD_PROFILE="${BUILD_PROFILE:-vpn_direct_ios}"
PROFILE_TAGS_FILE="${ROOT}/scripts/tags/${BUILD_PROFILE}.tags"
if [[ -f "${PROFILE_TAGS_FILE}" ]]; then
  BUILD_TAGS="$(tr -d ' \n' < "${PROFILE_TAGS_FILE}")"
elif [[ -f "${ROOT}/scripts/vpn_direct_ios.tags" ]]; then
  BUILD_TAGS="$(tr -d ' \n' < "${ROOT}/scripts/vpn_direct_ios.tags")"
fi
BUILD_TAGS="${BUILD_TAGS:-with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_naive_outbound,with_clash_api,with_xhttp,with_awg,with_lx_idle_suspend}"
CORE_VERSION="${CORE_VERSION:-0.1.0}"
GOMOBILE_MODULE="${GOMOBILE_MODULE:-github.com/sagernet/gomobile}"
GOMOBILE_REV="${GOMOBILE_REV:-v0.1.12}"
GOBIND_REV="${GOBIND_REV:-${GOMOBILE_REV}}"

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

if [[ -f "${CORE}/go.version" ]]; then
  PINNED="$(tr -d ' \n' < "${CORE}/go.version")"
  echo "note: donor pins Go ${PINNED}; current $(go version)"
fi

export PATH="${PATH}:$(go env GOPATH)/bin"

install_mobile_tools() {
  echo "installing ${GOMOBILE_MODULE}/cmd/gomobile@${GOMOBILE_REV} and gobind@${GOBIND_REV}…"
  go install "${GOMOBILE_MODULE}/cmd/gomobile@${GOMOBILE_REV}"
  go install "${GOMOBILE_MODULE}/cmd/gobind@${GOBIND_REV}"
  gomobile init || true
}

NEED_INSTALL=0
if ! command -v gomobile >/dev/null || ! command -v gobind >/dev/null; then
  NEED_INSTALL=1
elif [[ "${VPN_DIRECT_FORCE_GOMOBILE_INSTALL:-}" == "1" ]]; then
  NEED_INSTALL=1
fi
if [[ "${NEED_INSTALL}" -eq 1 ]]; then
  install_mobile_tools
fi

GOMOBILE_SHA="$(go env GOMODCACHE 2>/dev/null || true)"
# Resolve installed module version (sagernet fork first; fallback to golang.org/x/mobile).
GOMOBILE_BIN="$(command -v gomobile)"
GOMOBILE_MOD_INFO="$(go version -m "${GOMOBILE_BIN}" 2>/dev/null | awk '/github.com\/sagernet\/gomobile/{print $2; exit}' || true)"
if [[ -z "${GOMOBILE_MOD_INFO}" ]]; then
  GOMOBILE_MOD_INFO="$(go version -m "${GOMOBILE_BIN}" 2>/dev/null | awk '/golang.org\/x\/mobile/{print $2; exit}' || true)"
fi
GOMOBILE_SHA="${GOMOBILE_MOD_INFO:-${GOMOBILE_REV}}"

SING_BOX_SHA="unknown"
if git -C "${CORE}" rev-parse HEAD >/dev/null 2>&1; then
  SING_BOX_SHA="$(git -C "${CORE}" rev-parse HEAD)"
fi
SING_BOX_TAG="${SING_BOX_REV:-unknown}"
if git -C "${CORE}" describe --tags --exact-match >/dev/null 2>&1; then
  SING_BOX_TAG="$(git -C "${CORE}" describe --tags --exact-match)"
fi

echo "=== VPN Direct Libbox build ==="
echo "core:       ${CORE}"
echo "profile:    ${BUILD_PROFILE}"
echo "tags:       ${BUILD_TAGS}"
echo "version:    ${CORE_VERSION}"
echo "sing-box:   ${SING_BOX_SHA} (${SING_BOX_TAG})"
echo "gomobile:   ${GOMOBILE_SHA}"
echo "out:        ${OUT_FRAMEWORK}"

cd "${CORE}"

# Protocol / option / include overlays (mieru, etc.) onto stock sing-box-lx pin
bash "${ROOT}/scripts/prepare_core.sh"

OVERLAY_DIR="${ROOT}/core/overlays/libbox"
if [[ -d "${OVERLAY_DIR}" ]]; then
  echo "applying overlays from ${OVERLAY_DIR}"
  cp -f "${OVERLAY_DIR}"/*.go "${CORE}/experimental/libbox/"
fi

if [[ "${BUILD_TAGS}" == *with_awg* ]]; then
  if ! git submodule update --init --recursive; then
    echo "error: required AWG submodules failed to initialize (with_awg is mandatory for this profile)" >&2
    exit 1
  fi
fi

export LIBBOX_BUILD_TAGS="${BUILD_TAGS}"
export VPN_DIRECT_CORE_VERSION="${CORE_VERSION}"

APPLE_PLATFORM="${VPN_DIRECT_APPLE_PLATFORM:-ios,iossimulator,macos,tvos}"

echo "running build_libbox (platform=${APPLE_PLATFORM})…"
rm -rf "${CORE}/Libbox.xcframework" "${ROOT}/Libbox.xcframework.build"

if ! go run ./cmd/internal/build_libbox -target apple -platform "${APPLE_PLATFORM}" "$@"; then
  echo "error: build_libbox failed (platform=${APPLE_PLATFORM})" >&2
  exit 1
fi

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

# Fail closed: requested platforms must appear as xcframework slice dirs + Info.plist Library entries.
FOUND_SLICES="$(find "${CANDIDATE}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | tr '\n' ' ')"
PLIST_BLOB=""
if [[ -f "${CANDIDATE}/Info.plist" ]]; then
  PLIST_BLOB="$(plutil -p "${CANDIDATE}/Info.plist" 2>/dev/null || true)"
fi
REQUIRED_FAMILIES=()
MISSING_FAMILIES=()
NEED_TVOS=0
NEED_IOS=0
NEED_MACOS=0
IFS=',' read -r -a _REQ_PLATFORMS <<< "${APPLE_PLATFORM}"
for plat in "${_REQ_PLATFORMS[@]}"; do
  plat="$(echo "${plat}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
  [[ -z "${plat}" ]] && continue
  case "${plat}" in
    tvos|tvsimulator|tvossimulator) NEED_TVOS=1 ;;
    ios|iossimulator) NEED_IOS=1 ;;
    macos|maccatalyst) NEED_MACOS=1 ;;
  esac
done
[[ "${NEED_TVOS}" -eq 1 ]] && REQUIRED_FAMILIES+=("tvos")
[[ "${NEED_IOS}" -eq 1 ]] && REQUIRED_FAMILIES+=("ios")
[[ "${NEED_MACOS}" -eq 1 ]] && REQUIRED_FAMILIES+=("macos")
for fam in "${REQUIRED_FAMILIES[@]}"; do
  slice_ok=0
  plist_ok=0
  while IFS= read -r slice_dir; do
    [[ -z "${slice_dir}" ]] && continue
    base="$(basename "${slice_dir}")"
    case "${fam}" in
      ios)
        # ios-* only (tvos-* must not count)
        if [[ "${base}" == ios* ]]; then slice_ok=1; fi
        ;;
      tvos)
        if [[ "${base}" == *tvos* ]]; then slice_ok=1; fi
        ;;
      macos)
        if [[ "${base}" == *macos* ]]; then slice_ok=1; fi
        ;;
    esac
  done < <(find "${CANDIDATE}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  if [[ -n "${PLIST_BLOB}" ]]; then
    case "${fam}" in
      ios)
        # Exact platform token; avoid matching "tvos"
        if grep -Eq 'SupportedPlatform[[:space:]]*=>[[:space:]]*"ios"' <<< "${PLIST_BLOB}" \
          || grep -Eq '"LibraryIdentifier"[[:space:]]*=>[[:space:]]*"ios' <<< "${PLIST_BLOB}"; then
          plist_ok=1
        fi
        ;;
      tvos)
        if grep -Eqi 'tvos' <<< "${PLIST_BLOB}"; then plist_ok=1; fi
        ;;
      macos)
        if grep -Eqi 'macos' <<< "${PLIST_BLOB}"; then plist_ok=1; fi
        ;;
    esac
  else
    # No parsable Info.plist — rely on slice dirs only
    plist_ok="${slice_ok}"
  fi
  if [[ "${slice_ok}" -ne 1 || "${plist_ok}" -ne 1 ]]; then
    MISSING_FAMILIES+=("${fam}")
  fi
done
if [[ ${#MISSING_FAMILIES[@]} -gt 0 ]]; then
  echo "error: Libbox.xcframework missing required platform Library slices" >&2
  echo "  required: ${REQUIRED_FAMILIES[*]}" >&2
  echo "  found:    ${FOUND_SLICES:-"(none)"}" >&2
  echo "  missing:  ${MISSING_FAMILIES[*]}" >&2
  exit 1
fi

if [[ "${CANDIDATE}" != "${OUT_FRAMEWORK}" ]]; then
  rm -rf "${OUT_FRAMEWORK}"
  cp -R "${CANDIDATE}" "${OUT_FRAMEWORK}"
fi

BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}"

cat > "${ROOT}/Libbox.xcframework/VPNDirectCore.version" <<EOF
CORE_NAME=${CORE_NAME:-VPNDirectCore}
CORE_VERSION=${CORE_VERSION}
BUILD_PROFILE=${BUILD_PROFILE}
BUILD_TAGS=${BUILD_TAGS}
BUILT_AT=${BUILT_AT}
GO=$(go version)
GOMOBILE_SHA=${GOMOBILE_SHA}
SING_BOX_SHA=${SING_BOX_SHA}
SING_BOX_TAG=${SING_BOX_TAG}
SING_BOX_REV=${SING_BOX_TAG}
UPSTREAM_VERSION=${UPSTREAM_VERSION:-}
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}
EOF

echo "OK: ${OUT_FRAMEWORK}"
