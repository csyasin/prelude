#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
RELEASE_TAG="${1:-}"
if [[ ! "$RELEASE_TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "Usage: scripts/publish-release.sh vX.Y.Z" >&2
    exit 2
fi
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
command -v gh >/dev/null
test -f dist/Prelude.dmg
test -f dist/Prelude.dmg.sha256
(cd dist && shasum -a 256 -c Prelude.dmg.sha256)

cat > dist/release-notes.md <<'EOF'
支持 macOS 14+，适用于 Apple Silicon（M 系列芯片）。

下载 Prelude.dmg 后，将 Prelude.app 拖入 Applications。
Prelude.dmg.sha256 可用于核对下载文件的 SHA-256。

当前使用 ad-hoc 签名，尚未进行 Developer ID 签名与 Apple 公证，首次打开可能被 macOS 安全检查拦截。
EOF

if RELEASE_IS_DRAFT="$(gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --json isDraft --jq .isDraft)"; then
    if [[ "$RELEASE_IS_DRAFT" != true ]]; then
        echo "$RELEASE_TAG is already published. Release a new version instead." >&2
        exit 1
    fi
    gh release upload "$RELEASE_TAG" dist/Prelude.dmg dist/Prelude.dmg.sha256 \
        --repo "$GITHUB_REPOSITORY" --clobber
    gh release edit "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --draft=false
else
    gh release create "$RELEASE_TAG" dist/Prelude.dmg dist/Prelude.dmg.sha256 \
        --repo "$GITHUB_REPOSITORY" --verify-tag \
        --title "Prelude $RELEASE_TAG" --generate-notes \
        --notes-file dist/release-notes.md
fi
