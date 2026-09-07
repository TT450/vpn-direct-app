#!/usr/bin/env bash
# Build VPN Direct Libbox.xcframework from core/sing-box (sing-box-lx).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${ROOT}/core/sing-box"
OUT_FRAMEWORK="${ROOT}/Libbox.xcframework"
VERSION_FILE="${ROOT}/core/VERSION"
BUILD_STAMP_DIR="${ROOT}/.build/libbox"
BUILD_ID="libbox-$(date -u +%Y%m%dT%H%M%SZ)-$$"

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
if [[ ! -f "${PROFILE_TAGS_FILE}" ]]; then
  echo "error: missing required release tag profile ${PROFILE_TAGS_FILE}" >&2
  exit 1
fi
BUILD_TAGS="$(tr -d ' \n' < "${PROFILE_TAGS_FILE}")"
if [[ -z "${BUILD_TAGS}" ]]; then
  echo "error: empty BUILD_TAGS in ${PROFILE_TAGS_FILE}" >&2
  exit 1
fi
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
  CURRENT_GO="$(go env GOVERSION 2>/dev/null || go version | awk '{print $3}')"
  CURRENT_GO="${CURRENT_GO#go}"
  PINNED_TRIM="${PINNED#go}"
  if [[ -n "${PINNED_TRIM}" && "${CURRENT_GO}" != "${PINNED_TRIM}"* && "${CURRENT_GO}" != "${PINNED_TRIM}" ]]; then
    if [[ "${VPN_DIRECT_ALLOW_GO_MISMATCH:-}" == "1" ]]; then
      echo "warning: donor pins Go ${PINNED}; current ${CURRENT_GO} (allowed by VPN_DIRECT_ALLOW_GO_MISMATCH=1)" >&2
    else
      echo "error: Go version mismatch — donor pins ${PINNED}, current $(go version)" >&2
      echo "  set VPN_DIRECT_ALLOW_GO_MISMATCH=1 to override (not reproducible)" >&2
      exit 1
    fi
  else
    echo "note: Go pin OK (${PINNED} / $(go version))"
  fi
fi

export PATH="${PATH}:$(go env GOPATH)/bin"

install_mobile_tools() {
  echo "installing ${GOMOBILE_MODULE}/cmd/gomobile@${GOMOBILE_REV} and gobind@${GOBIND_REV}…"
  go install "${GOMOBILE_MODULE}/cmd/gomobile@${GOMOBILE_REV}"
  go install "${GOMOBILE_MODULE}/cmd/gobind@${GOBIND_REV}"
  # gomobile init is not required for sagernet/gomobile bind flows used by sing-box;
  # do not suppress failures if explicitly requested.
  if [[ "${VPN_DIRECT_GOMOBILE_INIT:-}" == "1" ]]; then
    gomobile init
  fi
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

GOMOBILE_BIN="$(command -v gomobile)"
GOMOBILE_MOD_INFO="$(go version -m "${GOMOBILE_BIN}" 2>/dev/null | awk '/github.com\/sagernet\/gomobile/{print $2; exit}' || true)"
if [[ -z "${GOMOBILE_MOD_INFO}" ]]; then
  GOMOBILE_MOD_INFO="$(go version -m "${GOMOBILE_BIN}" 2>/dev/null | awk '/golang.org\/x\/mobile/{print $2; exit}' || true)"
fi
GOMOBILE_SHA="${GOMOBILE_MOD_INFO:-${GOMOBILE_REV}}"

echo "=== VPN Direct Libbox build ==="
echo "core:       ${CORE}"
echo "profile:    ${BUILD_PROFILE}"
echo "tags:       ${BUILD_TAGS}"
echo "version:    ${CORE_VERSION}"
echo "gomobile:   ${GOMOBILE_SHA}"
echo "out:        ${OUT_FRAMEWORK}"
echo "build_id:   ${BUILD_ID}"

# Isolate stale artifacts BEFORE prepare/build so candidates cannot be reused.
mkdir -p "${BUILD_STAMP_DIR}"
rm -rf \
  "${CORE}/Libbox.xcframework" \
  "${CORE}/bind/Libbox.xcframework" \
  "${ROOT}/Libbox.xcframework.build" \
  "${OUT_FRAMEWORK}"

cd "${CORE}"

# Canonical prepare: exact pin + overlays + verify (fail-closed).
bash "${ROOT}/scripts/prepare_core.sh" --reset

# Provenance AFTER prepare.
SING_BOX_SHA="$(git -C "${CORE}" rev-parse HEAD)"
SING_BOX_TAG="${SING_BOX_REV:-unknown}"
if git -C "${CORE}" describe --tags --exact-match >/dev/null 2>&1; then
  SING_BOX_TAG="$(git -C "${CORE}" describe --tags --exact-match)"
fi
OVERLAY_HASH="$(
  {
    find "${ROOT}/core/overlays" -type f 2>/dev/null | sort | xargs shasum -a 256 2>/dev/null || true
    shasum -a 256 "${CORE}/go.mod" "${CORE}/go.sum" 2>/dev/null || true
  } | shasum -a 256 | awk '{print $1}'
)"
echo "sing-box:   ${SING_BOX_SHA} (${SING_BOX_TAG})"
echo "overlay:    ${OVERLAY_HASH}"

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

if ! go run ./cmd/internal/build_libbox -target apple -platform "${APPLE_PLATFORM}" "$@"; then
  echo "error: build_libbox failed (platform=${APPLE_PLATFORM})" >&2
  exit 1
fi

# Accept only artifacts produced under CORE for this invocation — never reuse root stale OUT.
CANDIDATE=""
for p in \
  "${CORE}/Libbox.xcframework" \
  "${CORE}/bind/Libbox.xcframework"
do
  if [[ -d "${p}" ]]; then
    CANDIDATE="${p}"
    break
  fi
done

if [[ -z "${CANDIDATE}" ]]; then
  echo "error: Libbox.xcframework not found under core after build" >&2
  find "${CORE}" -maxdepth 3 -name 'Libbox.xcframework' -type d 2>/dev/null || true
  exit 1
fi

# Fail closed: each requested platform must have an exact slice family.
FOUND_SLICES="$(find "${CANDIDATE}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | tr '\n' ' ')"
PLIST_BLOB=""
if [[ -f "${CANDIDATE}/Info.plist" ]]; then
  PLIST_BLOB="$(plutil -p "${CANDIDATE}/Info.plist" 2>/dev/null || true)"
fi

declare -a MISSING_PLATFORMS=()
IFS=',' read -r -a _REQ_PLATFORMS <<< "${APPLE_PLATFORM}"
for plat in "${_REQ_PLATFORMS[@]}"; do
  plat="$(echo "${plat}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
  [[ -z "${plat}" ]] && continue
  slice_ok=0
  while IFS= read -r slice_dir; do
    [[ -z "${slice_dir}" ]] && continue
    base="$(basename "${slice_dir}")"
    case "${plat}" in
      ios)
        # device ios-arm64* but not simulator
        if [[ "${base}" == ios-arm64* && "${base}" != *simulator* ]]; then slice_ok=1; fi
        ;;
      iossimulator)
        if [[ "${base}" == *simulator* && "${base}" == ios* ]]; then slice_ok=1; fi
        ;;
      tvos)
        if [[ "${base}" == tvos-arm64* && "${base}" != *simulator* ]]; then slice_ok=1; fi
        ;;
      tvsimulator|tvossimulator)
        if [[ "${base}" == *simulator* && "${base}" == *tvos* ]]; then slice_ok=1; fi
        ;;
      macos)
        if [[ "${base}" == macos* ]]; then slice_ok=1; fi
        ;;
      maccatalyst)
        if [[ "${base}" == *maccatalyst* || "${base}" == *catalyst* ]]; then slice_ok=1; fi
        ;;
      *)
        echo "error: unknown requested platform token: ${plat}" >&2
        exit 1
        ;;
    esac
  done < <(find "${CANDIDATE}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  if [[ "${slice_ok}" -ne 1 ]]; then
    MISSING_PLATFORMS+=("${plat}")
  fi
done

if [[ ${#MISSING_PLATFORMS[@]} -gt 0 ]]; then
  echo "error: Libbox.xcframework missing exact requested platform slices" >&2
  echo "  requested: ${APPLE_PLATFORM}" >&2
  echo "  found:     ${FOUND_SLICES:-"(none)"}" >&2
  echo "  missing:   ${MISSING_PLATFORMS[*]}" >&2
  exit 1
fi

rm -rf "${OUT_FRAMEWORK}"
cp -R "${CANDIDATE}" "${OUT_FRAMEWORK}"

# Marker that this OUT_FRAMEWORK was produced by this build_id.
BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}"
MARKER="${OUT_FRAMEWORK}/VPNDirectCore.version"
cat > "${MARKER}" <<EOF
CORE_NAME=${CORE_NAME:-VPNDirectCore}
CORE_VERSION=${CORE_VERSION}
BUILD_PROFILE=${BUILD_PROFILE}
BUILD_TAGS=${BUILD_TAGS}
BUILT_AT=${BUILT_AT}
BUILD_ID=${BUILD_ID}
GO=$(go version)
GOMOBILE_SHA=${GOMOBILE_SHA}
SING_BOX_SHA=${SING_BOX_SHA}
SING_BOX_TAG=${SING_BOX_TAG}
SING_BOX_REV=${SING_BOX_REV:-${SING_BOX_TAG}}
UPSTREAM_VERSION=${UPSTREAM_VERSION:-}
OVERLAY_HASH=${OVERLAY_HASH}
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}
EOF

echo "${BUILD_ID}" > "${BUILD_STAMP_DIR}/last_build_id"
echo "OK: ${OUT_FRAMEWORK}"
echo "slices: ${FOUND_SLICES}"
