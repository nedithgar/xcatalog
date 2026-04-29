#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:h}

cd "$REPO_ROOT"

export XCATALOG_GIT_COMMIT=${XCATALOG_GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || true)}
BUILD_CONFIGURATION=${XCATALOG_BUILD_CONFIGURATION:-debug}
BUILD_CONFIGURATION=${BUILD_CONFIGURATION:l}

case "$BUILD_CONFIGURATION" in
    debug|release)
        ;;
    *)
        echo "XCATALOG_BUILD_CONFIGURATION must be 'debug' or 'release' (got '$BUILD_CONFIGURATION')" >&2
        exit 64
        ;;
esac

export XCATALOG_BUILD_CONFIGURATION=$BUILD_CONFIGURATION
export XCATALOG_BUILD_DATE=${XCATALOG_BUILD_DATE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}

swift build -c "$XCATALOG_BUILD_CONFIGURATION" --product xcatalog >&2
BUILD_BIN_PATH="$REPO_ROOT/.build/$XCATALOG_BUILD_CONFIGURATION"

if [[ ! -x "$BUILD_BIN_PATH/xcatalog" ]]; then
    # Some SwiftPM layouts omit the .build/debug or .build/release convenience
    # symlink. Use the active host triple instead of globbing stale artifacts.
    TARGET_TRIPLE=$(swift -print-target-info | plutil -extract target.unversionedTriple raw -o - -)
    BUILD_BIN_PATH="$REPO_ROOT/.build/$TARGET_TRIPLE/$XCATALOG_BUILD_CONFIGURATION"
fi

if [[ ! -x "$BUILD_BIN_PATH/xcatalog" ]]; then
    echo "Unable to locate built xcatalog executable for '$XCATALOG_BUILD_CONFIGURATION' configuration" >&2
    exit 72
fi

exec "$BUILD_BIN_PATH/xcatalog" mcp "$@"
