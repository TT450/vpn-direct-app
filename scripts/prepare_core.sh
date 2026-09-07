#!/usr/bin/env bash
# Canonical Core tree preparation for VPN Direct.
# Release invariant: exact configured donor commit + deterministic local overlays; never repair deps online.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${ROOT}/core/sing-box"
VERSION_FILE="${ROOT}/core/VERSION"
MODE="apply"

for arg in "$@"; do
  case "${arg}" in
    --verify) MODE="verify" ;;
    --reset) MODE="reset" ;;
    -h|--help)
      echo "usage: $0 [--verify|--reset]"
      exit 0
      ;;
    *) echo "error: unknown argument ${arg}" >&2; exit 2 ;;
  esac
done

load_version() {
  [[ -f "${VERSION_FILE}" ]] || { echo "error: missing ${VERSION_FILE}" >&2; exit 1; }
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
    [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] && export "${line?}"
  done < "${VERSION_FILE}"
  [[ -n "${SING_BOX_REV:-}" ]] || { echo "error: SING_BOX_REV must be pinned in core/VERSION" >&2; exit 1; }
}

resolve_pin() {
  local resolved
  resolved="$(git -C "${CORE}" rev-parse --verify "${SING_BOX_REV}^{commit}" 2>/dev/null || true)"
  if [[ -z "${resolved}" ]]; then
    resolved="$(git -C "${CORE}" rev-parse --verify "refs/tags/${SING_BOX_REV}^{commit}" 2>/dev/null || true)"
  fi
  [[ -n "${resolved}" ]] || { echo "error: configured Core pin ${SING_BOX_REV} is not resolvable" >&2; exit 1; }
  printf '%s\n' "${resolved}"
}

verify_exact_base() {
  local expected actual
  expected="$(resolve_pin)"
  actual="$(git -C "${CORE}" rev-parse HEAD)"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "error: core/sing-box HEAD ${actual} != configured ${SING_BOX_REV} (${expected})" >&2
    echo "run: scripts/prepare_core.sh --reset" >&2
    exit 1
  fi
  echo "prepare_core: exact base ${SING_BOX_REV} (${expected})"
}

require_file() {
  [[ -f "${CORE}/$1" ]] || { echo "MISSING ${CORE}/$1" >&2; return 1; }
}

require_marker() {
  local rel="$1" marker="$2"
  grep -q -- "${marker}" "${CORE}/${rel}" 2>/dev/null || {
    echo "MISSING marker '${marker}' in ${CORE}/${rel}" >&2
    return 1
  }
}

verify_feature_tree() {
  local missing=0

  # Local Mieru overlay.
  for rel in include/mieru.go include/mieru_stub.go option/mieru.go protocol/mieru/outbound.go protocol/mieru/inbound.go; do
    require_file "${rel}" || missing=1
  done
  require_marker constant/proxy.go TypeMieru || missing=1
  require_marker include/registry.go registerMieruOutbound || missing=1
  require_marker go.mod github.com/enfein/mieru/v3 || missing=1

  # Mandatory capabilities supplied by the exact sing-box-lx donor pin.
  require_file option/wireguard.go || missing=1
  require_file option/wireguard_awg.go || missing=1
  require_marker option/wireguard.go WireGuardEndpointOptions || missing=1
  require_marker option/wireguard_awg.go HeaderProtectionKey || missing=1
  require_marker option/wireguard_awg.go RandomTrailers || missing=1
  require_marker include/registry.go WireGuard || missing=1

  # XHTTP / MASQUE / VLESS encryption are release-profile requirements. Marker checks intentionally
  # fail when donor layout/schema changes so an upgrade cannot silently lose a capability.
  if ! grep -Rqs --include='*.go' 'xhttp' "${CORE}/option" "${CORE}/include" "${CORE}/transport" 2>/dev/null; then
    echo "MISSING xhttp registration/options in pinned Core" >&2; missing=1
  fi
  if ! grep -Rqs --include='*.go' 'masque' "${CORE}/option" "${CORE}/include" "${CORE}/protocol" 2>/dev/null; then
    echo "MISSING MASQUE registration/options in pinned Core" >&2; missing=1
  fi
  if ! grep -Rqs --include='*.go' 'encryption' "${CORE}/protocol/vless" "${CORE}/option" 2>/dev/null; then
    echo "MISSING VLESS encryption implementation/options in pinned Core" >&2; missing=1
  fi

  if [[ "${missing}" -ne 0 ]]; then
    echo "prepare_core verify FAILED" >&2
    exit 1
  fi
  echo "prepare_core verify OK (exact pin + mandatory feature tree)"
}

[[ -d "${CORE}/.git" || -f "${CORE}/.git" ]] || {
  echo "error: ${CORE} missing or is not initialized — run git submodule update --init --recursive" >&2
  exit 1
}
load_version

if [[ "${MODE}" == "reset" ]]; then
  echo "prepare_core: resetting to ${SING_BOX_REV}"
  (
    cd "${CORE}"
    git fetch --tags origin
    target="$(git rev-parse --verify "${SING_BOX_REV}^{commit}" 2>/dev/null || git rev-parse --verify "refs/tags/${SING_BOX_REV}^{commit}")"
    git checkout --detach --force "${target}"
    git clean -fd
    git submodule update --init --recursive
  )
fi

# In BOTH apply and verify modes prove we are anchored to the exact configured donor base.
verify_exact_base

if [[ "${MODE}" != "verify" ]]; then
  echo "prepare_core: applying deterministic local overlays"
  bash "${ROOT}/scripts/apply_singbox_overlays.sh"
fi

# Never `go get`, `go mod tidy`, or otherwise mutate dependency pins here. The overlay must carry
# a complete go.mod/go.sum change. Missing dependencies are a source-tree error, not a build repair.
verify_feature_tree

echo "prepare_core OK"
