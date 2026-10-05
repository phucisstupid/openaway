#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

ARCHITECTURES=()
if [[ "${1:-}" == "--universal" && $# -eq 1 ]]; then
    ARCHITECTURES=(arm64 x86_64)
elif [[ $# -ne 0 ]]; then
    echo "Usage: $0 [--universal]" >&2
    exit 1
fi

# Keep compiler and package caches within the checkout, including in restricted CI.
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/ModuleCache"
SWIFT_BUILD_OPTIONS=(--build-system native --disable-sandbox --cache-path "$PROJECT_ROOT/.build/cache" --config-path "$PROJECT_ROOT/.build/config" --security-path "$PROJECT_ROOT/.build/security")
# Assemble and sign outside synced folders, where Finder metadata can invalidate signing.
APP_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/openaway-build.XXXXXX")"
trap 'rm -rf "$APP_WORK_DIR"' EXIT
APP_DIR="$APP_WORK_DIR/OpenAway.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
if [[ ${#ARCHITECTURES[@]} -gt 0 ]]; then
    BINARIES=()
    for ARCHITECTURE in "${ARCHITECTURES[@]}"; do
        ARCH_OPTIONS=(--arch "$ARCHITECTURE" --scratch-path "$PROJECT_ROOT/.build/universal/$ARCHITECTURE")
        swift build "${SWIFT_BUILD_OPTIONS[@]}" -c release "${ARCH_OPTIONS[@]}"
        BUILD_DIR="$(swift build "${SWIFT_BUILD_OPTIONS[@]}" -c release "${ARCH_OPTIONS[@]}" --show-bin-path)"
        BINARIES+=("$BUILD_DIR/OpenAway")
    done
    lipo -create "${BINARIES[@]}" -output "$APP_DIR/Contents/MacOS/OpenAway"
    lipo "$APP_DIR/Contents/MacOS/OpenAway" -verify_arch arm64
    lipo "$APP_DIR/Contents/MacOS/OpenAway" -verify_arch x86_64
else
    swift build "${SWIFT_BUILD_OPTIONS[@]}" -c release
    BUILD_DIR="$(swift build "${SWIFT_BUILD_OPTIONS[@]}" -c release --show-bin-path)"
    cp -X "$BUILD_DIR/OpenAway" "$APP_DIR/Contents/MacOS/OpenAway"
fi
cp -X "$PROJECT_ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp -X "$PROJECT_ROOT/LICENSE" "$APP_DIR/Contents/Resources/LICENSE.txt"
if [[ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]]; then
    cp -X "$PROJECT_ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
chmod +x "$APP_DIR/Contents/MacOS/OpenAway"
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
# Avoid carrying Finder or cloud-provider metadata into the downloadable bundle.
mkdir -p "$PROJECT_ROOT/dist"
ditto --norsrc --noextattr --noqtn -c -k --keepParent "$APP_DIR" "$PROJECT_ROOT/dist/OpenAway-macos.zip"
rm -rf "$PROJECT_ROOT/dist/OpenAway.app"
ditto --norsrc --noextattr --noqtn "$APP_DIR" "$PROJECT_ROOT/dist/OpenAway.app"
echo "Built $PROJECT_ROOT/dist/OpenAway.app"
echo "Packaged $PROJECT_ROOT/dist/OpenAway-macos.zip"
echo "Open it with: open \"$PROJECT_ROOT/dist/OpenAway.app\""
