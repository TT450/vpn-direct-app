#!/usr/bin/env bash
# Restores the tracked empty DirectBackendLocal.ets stub when missing.
# Does not overwrite a private skip-worktree override that already exists.
# No hosts, routes, or secrets — safe to commit and run on public clones.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND="$ROOT/entry/src/main/ets/backend"
EXAMPLE="$BACKEND/DirectBackendLocal.example.ets"
LOCAL="$BACKEND/DirectBackendLocal.ets"

if [[ ! -f "$EXAMPLE" ]]; then
  echo "missing example: $EXAMPLE" >&2
  exit 1
fi

if [[ -f "$LOCAL" ]]; then
  echo "DirectBackendLocal.ets already present"
  exit 0
fi

cp "$EXAMPLE" "$LOCAL"
echo "created $LOCAL from example (empty stub)"
