#!/bin/bash
# ================================================================
# build_macos.sh — Build macOS bgfx (with Vulkan patches)
#
# Usage: ./build_macos.sh [arm64|x64|all]
# Default: all
# Output: libs/hxbgfx/lib/macos/libbgfx.a, libbx.a, libbimg.a
# ================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
LIB_OUT="$SCRIPT_DIR/lib/macos"
ARCH="${1:-all}"

for cmd in git make clang clang++; do
    command -v "$cmd" >/dev/null 2>&1 || err "Missing dependency: $cmd (install Xcode CLT: xcode-select --install)"
done

info "=== Building macOS bgfx (with Vulkan patches) ==="

# Clone sources
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
for repo in bgfx bx bimg; do
    if [ ! -d "$repo" ]; then
        info "Cloning $repo..."
        git clone --depth 1 https://github.com/bkaradzic/${repo}.git "$repo"
    else
        info "$repo already exists, skipping"
    fi
done

# ==== macOS: no Vulkan patches needed ====
# macOS uses Metal, not Vulkan. The VK patches (InternalData, getInternal)
# are only needed for DLSS/XeSS on Windows/Linux. We use the stock bgfx.
info "Skipping Vulkan patches (macOS uses Metal, not Vulkan)"

# Build function
BX_DIR="$BUILD_DIR/bx"
GENIE="$BX_DIR/tools/bin/darwin/genie"
cd "$BUILD_DIR/bgfx"

build_arch() {
    local genie_arch="$1"
    local out_subdir="$2"

    info "Generating build files ($genie_arch)..."
    "$GENIE" --gcc="$genie_arch" gmake

    cd ".build/projects/gmake-$genie_arch"
    info "Building bgfx, bx, bimg..."
    make bgfx bx bimg config=release64 -j$(sysctl -n hw.ncpu)

    BIN="$BUILD_DIR/bgfx/.build/$out_subdir/bin"
    cp -v "$BIN/libbgfxRelease.a"   "$LIB_OUT/libbgfx.a"
    cp -v "$BIN/libbxRelease.a"     "$LIB_OUT/libbx.a"
    cp -v "$BIN/libbimgRelease.a"   "$LIB_OUT/libbimg.a"

    info "Building shaderc ($genie_arch)..."
    make shaderc config=release64 -j$(sysctl -n hw.ncpu)
    cp -v "$BIN/shadercRelease" "$SCRIPT_DIR/../tools/shaderc" 2>/dev/null || true
    cd "$BUILD_DIR/bgfx"
}

mkdir -p "$LIB_OUT"

case "$ARCH" in
    arm64)  build_arch "osx-arm64" "osx-arm64" ;;
    x64)    build_arch "osx-x64" "osx-x64" ;;
    all)
        ARCH_NAME=$(uname -m)
        [ "$ARCH_NAME" = "arm64" ] && build_arch "osx-arm64" "osx-arm64"
        build_arch "osx-x64" "osx-x64"
        ;;
    *)      err "Unknown arch: $ARCH (options: arm64, x64, all)" ;;
esac

echo ""
info "=================================================================="
info "macOS bgfx build complete!"
info "Output: $LIB_OUT"
ls -lh "$LIB_OUT/"
info "=================================================================="
