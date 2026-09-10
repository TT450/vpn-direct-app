#!/usr/bin/env bash
# Write build/build-manifest.txt with CI/repro metadata (no secrets).
# Fields: date, git sha, core VERSION pin, SHA256 of one Libbox binary if findable.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${ROOT}/build"
OUT="${OUT_DIR}/build-manifest.txt"

mkdir -p "${OUT_DIR}"

DATE_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
GIT_SHA="$(git -C "${ROOT}" rev-parse HEAD 2>/dev/null || echo "unknown")"

CORE_VERSION_PIN="unknown"
if [[ -f "${ROOT}/core/VERSION" ]]; then
  # Prefer SING_BOX_REV; fall back to CORE_VERSION.
  CORE_VERSION_PIN="$(
    awk -F= '
      /^SING_BOX_REV=/ { rev=$2 }
      /^CORE_VERSION=/ { cv=$2 }
      END {
        if (rev != "") print rev
        else if (cv != "") print cv
        else print "unknown"
      }
    ' "${ROOT}/core/VERSION"
  )"
fi

LIBBOX_SHA256="not-found"
LIBBOX_BIN_PATH=""
if [[ -d "${ROOT}/Libbox.xcframework" ]]; then
  LIBBOX_BIN_PATH="$(find "${ROOT}/Libbox.xcframework" -type f -name Libbox 2>/dev/null | head -1 || true)"
  if [[ -n "${LIBBOX_BIN_PATH}" && -f "${LIBBOX_BIN_PATH}" ]]; then
    if command -v shasum >/dev/null 2>&1; then
      LIBBOX_SHA256="$(shasum -a 256 "${LIBBOX_BIN_PATH}" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
      LIBBOX_SHA256="$(sha256sum "${LIBBOX_BIN_PATH}" | awk '{print $1}')"
    else
      LIBBOX_SHA256="unavailable"
    fi
  fi
fi

{
  echo "date=${DATE_UTC}"
  echo "git_sha=${GIT_SHA}"
  echo "core_version_pin=${CORE_VERSION_PIN}"
  echo "libbox_sha256=${LIBBOX_SHA256}"
  if [[ -n "${LIBBOX_BIN_PATH}" ]]; then
    echo "libbox_binary=${LIBBOX_BIN_PATH#"${ROOT}/"}"
  else
    echo "libbox_binary="
  fi
} > "${OUT}"

echo "Wrote ${OUT}"
cat "${OUT}"
