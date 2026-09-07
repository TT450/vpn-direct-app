#!/usr/bin/env bash
# Build VPN Direct Libbox.xcframework from the exact pinned sing-box-lx tree.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${ROOT}/core/sing-box"
OUT_FRAMEWORK="${ROOT}/Libbox.xcframework"
VERSION_FILE="${ROOT}/core/VERSION"

load_version() {
  [[ -f "${VERSION_FILE}" ]] || { echo "error: missing ${VERSION_FILE}" >&2; exit 1; }
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
    [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] && export "${line?}"
  done < "${VERSION_FILE}"
}
load_version

BUILD_PROFILE="${BUILD_PROFILE:-vpn_direct_ios}"
PROFILE_TAGS_FILE="${ROOT}/scripts/tags/${BUILD_PROFILE}.tags"
[[ -f "${PROFILE_TAGS_FILE}" ]] || {
  echo "error: release build profile is missing: ${PROFILE_TAGS_FILE}" >&2
  exit 1
}
BUILD_TAGS="$(tr -d ' \n' < "${PROFILE_TAGS_FILE}")"
[[ -n "${BUILD_TAGS}" ]] || { echo "error: empty build tags profile ${BUILD_PROFILE}" >&2; exit 1; }

CORE_VERSION="${CORE_VERSION:-0.1.0}"
GOMOBILE_MODULE="${GOMOBILE_MODULE:-github.com/sagernet/gomobile}"
GOMOBILE_REV="${GOMOBILE_REV:-v0.1.12}"
GOBIND_REV="${GOBIND_REV:-${GOMOBILE_REV}}"
APPLE_PLATFORM="${VPN_DIRECT_APPLE_PLATFORM:-ios,iossimulator,macos,tvos}"

[[ -d "${CORE}" ]] || { echo "error: missing ${CORE}; initialize submodules" >&2; exit 1; }
command -v go >/dev/null || { echo "error: go not installed" >&2; exit 1; }

# Go is part of the reproducibility contract. Do not merely print a mismatch.
if [[ -f "${CORE}/go.version" ]]; then
  PINNED_GO="$(tr -d ' \n' < "${CORE}/go.version")"
  CURRENT_GO="$(go version | awk '{print $3}')"
  if [[ "${CURRENT_GO}" != "${PINNED_GO}" ]]; then
    echo "error: Core requires ${PINNED_GO}, current toolchain is ${CURRENT_GO}" >&2
    exit 1
  fi
fi

export PATH="${PATH}:$(go env GOPATH)/bin"
install_mobile_tools() {
  echo "installing pinned gomobile/gobind…"
  go install "${GOMOBILE_MODULE}/cmd/gomobile@${GOMOBILE_REV}"
  go install "${GOMOBILE_MODULE}/cmd/gobind@${GOBIND_REV}"
  # Modern VPN Direct build does not rely on `gomobile init`; do not hide an init error with `|| true`.
}

if ! command -v gomobile >/dev/null || ! command -v gobind >/dev/null || [[ "${VPN_DIRECT_FORCE_GOMOBILE_INSTALL:-}" == "1" ]]; then
  install_mobile_tools
fi

GOMOBILE_BIN="$(command -v gomobile)"
GOMOBILE_MOD_INFO="$(go version -m "${GOMOBILE_BIN}" 2>/dev/null | awk '/github.com\/sagernet\/gomobile/{print $2; exit}' || true)"
[[ -n "${GOMOBILE_MOD_INFO}" ]] || GOMOBILE_MOD_INFO="${GOMOBILE_REV}"

# Canonical preparation always resets to the configured pin, then applies deterministic overlays.
bash "${ROOT}/scripts/prepare_core.sh" --reset

OVERLAY_DIR="${ROOT}/core/overlays/libbox"
if [[ -d "${OVERLAY_DIR}" ]]; then
  shopt -s nullglob
  overlay_files=("${OVERLAY_DIR}"/*.go)
  shopt -u nullglob
  if [[ ${#overlay_files[@]} -gt 0 ]]; then
    cp -f "${overlay_files[@]}" "${CORE}/experimental/libbox/"
  fi
fi

if [[ "${BUILD_TAGS}" == *with_awg* ]]; then
  git -C "${CORE}" submodule update --init --recursive
fi

# Provenance is computed AFTER preparation, never before it.
SING_BOX_BASE_SHA="$(git -C "${CORE}" rev-parse HEAD)"
SING_BOX_STATUS="$(git -C "${CORE}" status --porcelain=v1 --untracked-files=all)"
GO_MOD_SHA256="$(shasum -a 256 "${CORE}/go.mod" | awk '{print $1}')"
GO_SUM_SHA256="$(shasum -a 256 "${CORE}/go.sum" | awk '{print $1}')"
OVERLAY_SHA256="$(find "${ROOT}/core/overlays" -type f -print0 2>/dev/null | sort -z | xargs -0 cat 2>/dev/null | shasum -a 256 | awk '{print $1}')"

export LIBBOX_BUILD_TAGS="${BUILD_TAGS}"
export VPN_DIRECT_CORE_VERSION="${CORE_VERSION}"

printf '%s\n' \
  "=== VPN Direct Libbox build ===" \
  "core pin:    ${SING_BOX_REV}" \
  "base sha:    ${SING_BOX_BASE_SHA}" \
  "profile:     ${BUILD_PROFILE}" \
  "tags:        ${BUILD_TAGS}" \
  "platforms:   ${APPLE_PLATFORM}" \
  "go:          $(go version)" \
  "gomobile:    ${GOMOBILE_MOD_INFO}"

cd "${CORE}"

# Remove EVERY candidate from previous invocations, including the final root framework.
rm -rf \
  "${CORE}/Libbox.xcframework" \
  "${CORE}/bind/Libbox.xcframework" \
  "${ROOT}/Libbox.xcframework.build" \
  "${OUT_FRAMEWORK}"

BUILD_START_EPOCH="$(date +%s)"
go run ./cmd/internal/build_libbox -target apple -platform "${APPLE_PLATFORM}" "$@"

CANDIDATE=""
for p in "${CORE}/Libbox.xcframework" "${CORE}/bind/Libbox.xcframework" "${OUT_FRAMEWORK}"; do
  if [[ -d "${p}" ]]; then
    CANDIDATE="${p}"
    break
  fi
done
[[ -n "${CANDIDATE}" ]] || { echo "error: Libbox.xcframework not produced by this build" >&2; exit 1; }

# It cannot be stale because all accepted candidate paths were removed immediately before build.
CANDIDATE_MTIME="$(stat -f %m "${CANDIDATE}" 2>/dev/null || stat -c %Y "${CANDIDATE}")"
if (( CANDIDATE_MTIME < BUILD_START_EPOCH )); then
  echo "error: candidate framework predates current build invocation" >&2
  exit 1
fi

slice_names="$(find "${CANDIDATE}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)"
require_slice() {
  local platform="$1" pattern=""
  case "${platform}" in
    ios) pattern='^ios-[^-]+($|_[^-]+$)' ;;
    iossimulator) pattern='^ios-.*-simulator$' ;;
    macos) pattern='^macos-' ;;
    maccatalyst) pattern='^ios-.*-maccatalyst$' ;;
    tvos) pattern='^tvos-[^-]+($|_[^-]+$)' ;;
    tvossimulator|tvsimulator) pattern='^tvos-.*-simulator$' ;;
    *) echo "error: unsupported requested Apple platform '${platform}'" >&2; exit 1 ;;
  esac
  if ! grep -Eq "${pattern}" <<< "${slice_names}"; then
    echo "error: missing exact requested slice '${platform}'" >&2
    echo "found slices:" >&2
    sed 's/^/  /' <<< "${slice_names}" >&2
    exit 1
  fi
}
IFS=',' read -r -a requested <<< "${APPLE_PLATFORM}"
for platform in "${requested[@]}"; do
  platform="$(tr -d '[:space:]' <<< "${platform}" | tr '[:upper:]' '[:lower:]')"
  [[ -z "${platform}" ]] || require_slice "${platform}"
done

if [[ "${CANDIDATE}" != "${OUT_FRAMEWORK}" ]]; then
  cp -R "${CANDIDATE}" "${OUT_FRAMEWORK}"
fi
[[ -f "${OUT_FRAMEWORK}/Info.plist" ]] || { echo "error: final xcframework missing Info.plist" >&2; exit 1; }

BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}"
DIRTY_HASH="$(printf '%s' "${SING_BOX_STATUS}" | shasum -a 256 | awk '{print $1}')"
cat > "${OUT_FRAMEWORK}/VPNDirectCore.version" <<EOF
CORE_NAME=${CORE_NAME:-VPNDirectCore}
CORE_VERSION=${CORE_VERSION}
BUILD_PROFILE=${BUILD_PROFILE}
BUILD_TAGS=${BUILD_TAGS}
BUILT_AT=${BUILT_AT}
GO=$(go version)
GOMOBILE_MODULE=${GOMOBILE_MODULE}
GOMOBILE_REV=${GOMOBILE_REV}
GOBIND_REV=${GOBIND_REV}
GOMOBILE_ACTUAL=${GOMOBILE_MOD_INFO}
SING_BOX_REV=${SING_BOX_REV}
SING_BOX_BASE_SHA=${SING_BOX_BASE_SHA}
CORE_WORKTREE_STATUS_SHA256=${DIRTY_HASH}
OVERLAY_SHA256=${OVERLAY_SHA256}
GO_MOD_SHA256=${GO_MOD_SHA256}
GO_SUM_SHA256=${GO_SUM_SHA256}
UPSTREAM_VERSION=${UPSTREAM_VERSION:-}
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}
EOF

echo "OK: ${OUT_FRAMEWORK}"
