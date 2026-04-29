#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:h}

cd "$REPO_ROOT"

export XCATALOG_GIT_COMMIT=${XCATALOG_GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || true)}
export XCATALOG_BUILD_CONFIGURATION=${XCATALOG_BUILD_CONFIGURATION:-debug}
export XCATALOG_BUILD_DATE=${XCATALOG_BUILD_DATE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}

swift build -c debug --product xcatalog >&2

exec "$REPO_ROOT/.build/debug/xcatalog" mcp "$@"
