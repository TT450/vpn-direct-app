#!/usr/bin/env bash
set -euo pipefail

DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}"
DEVECO_HOME="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"
HARMONY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

HVIGOR="${HVIGOR:-$DEVECO_HOME/tools/hvigor/bin/hvigorw}"
OHPM="${OHPM:-$DEVECO_HOME/tools/ohpm/bin/ohpm}"

[[ -x "$HVIGOR" ]] || { echo "Missing hvigor: $HVIGOR" >&2; exit 2; }
[[ -x "$OHPM" ]] || { echo "Missing ohpm: $OHPM" >&2; exit 2; }
[[ -d "$DEVECO_SDK_HOME" ]] || { echo "Missing DevEco SDK: $DEVECO_SDK_HOME" >&2; exit 2; }

cd "$HARMONY_ROOT"
export DEVECO_SDK_HOME

"$OHPM" install
"$HVIGOR" --version
"$HVIGOR" assembleHap --mode module -p product=default

echo "HAP build completed. Inspect harmony/entry/build/default/outputs/default/ for the generated HAP."
