#!/bin/bash
set -euo pipefail
exec > /tmp/v107_release.log 2>&1
echo "START $(date)"
ROOT="/Users/elshan/Direct VPN Client"
cd "$ROOT"

# Kill stuck git if any
pgrep -lf git || true
if ! pgrep -x git >/dev/null 2>&1; then
  rm -f .git/index.lock .git/refs/heads/*.lock 2>/dev/null || true
  find .git -name '*.lock' -maxdepth 2 -type f -delete 2>/dev/null || true
fi

echo "=== status ==="
git status -sb || true
echo "=== log ==="
git log -3 --oneline || true

# Ignore SPM build
if ! grep -q 'VPNDirectParserPackage/.build' .gitignore 2>/dev/null; then
  printf '\n# Swift package test build\ntests/VPNDirectParserPackage/.build/\n' >> .gitignore
fi

# Bump MARKETING_VERSION 1.0.6 -> 1.0.7 in pbxproj
if grep -q 'MARKETING_VERSION = 1.0.6' sing-box.xcodeproj/project.pbxproj 2>/dev/null; then
  sed -i '' 's/MARKETING_VERSION = 1.0.6;/MARKETING_VERSION = 1.0.7;/g' sing-box.xcodeproj/project.pbxproj
  echo "bumped pbxproj MARKETING_VERSION"
fi

# Bump docs mentioning v1.0.6 as current app release if present
for f in README.md ROADMAP.md docs/core/PROTOCOL_MATRIX.md docs/core/FINAL_IMPLEMENTATION_AUDIT.md; do
  if [[ -f "$f" ]] && grep -q 'v1\.0\.6\|1\.0\.6' "$f"; then
    # careful: only product release mentions — leave historical notes
    sed -i '' 's/app release \*\*v1\.0\.6\*\*/app release **v1.0.7**/g' "$f" || true
    sed -i '' 's/Latest.*v1\.0\.6/Latest published: **v1.0.7**/g' "$f" || true
  fi
done

echo "=== add ==="
git add -A
# unstage huge / build artifacts if staged
git reset HEAD -- 'tests/VPNDirectParserPackage/.build' 2>/dev/null || true
git reset HEAD -- 'Libbox.xcframework' 2>/dev/null || true
git reset HEAD -- 'Libbox.xcframework.stock' 2>/dev/null || true
git reset HEAD -- 'core/sing-box/sing-box' 2>/dev/null || true
git reset HEAD -- 'build/' 2>/dev/null || true

echo "=== staged stat ==="
git diff --cached --stat | tail -50

git commit -m "$(cat <<'EOF'
Release v1.0.7: battle-qualification ready (prepare_core, panels, Swift parser tests)

EOF
)" || echo "COMMIT_MAYBE_EMPTY"

git tag -a v1.0.7 -m "v1.0.7" 2>/dev/null || git tag v1.0.7 2>/dev/null || echo "tag exists"

echo "=== push ==="
git push -u origin HEAD
git push origin v1.0.7

echo "=== release ==="
gh release create v1.0.7 --title "v1.0.7" --notes "$(cat <<'EOF'
## Summary
Battle-qualification implementation ready for Core + Apple client.

- prepare_core overlays before parser/Libbox/CI (Mieru green)
- protocol-matrix + panel-compatibility SoT; 12 panel dossiers + fixtures
- Swift VPNDirectParserTests (15) in check-fixtures
- Xray attributes-only, Clash nested harden, HTTP ETag/304
- Unsigned SFI/SFM/SFT CI compile jobs + build-manifest artifacts

## Not claimed as tested
Live VPS panel evidence and iPhone device qualification still required before matrix `tested`.

EOF
)" || gh release edit v1.0.7 --notes "v1.0.7 battle-qualification ready" || true

echo "DONE $(date)"
git rev-parse HEAD
git rev-parse v1.0.7
gh release view v1.0.7 --json url -q .url || true
