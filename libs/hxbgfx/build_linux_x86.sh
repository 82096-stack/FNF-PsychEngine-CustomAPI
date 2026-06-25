#!/bin/bash
# ================================================================
# build_linux_x86.sh — Build Linux x86 (32-bit) bgfx (with Vulkan patches)
#
# Usage: ./build_linux_x86.sh
# Output: libs/hxbgfx/lib/linux/x86/libbgfx.a, libbx.a, libbimg.a
#
# Prerequisites (Ubuntu/Debian):
#   sudo dpkg --add-architecture i386
#   sudo apt update
#   sudo apt install gcc-multilib g++-multilib libc6-dev-i386
# ================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
LIB_OUT="$SCRIPT_DIR/lib/linux/x86"

for cmd in git make gcc g++; do
    command -v "$cmd" >/dev/null 2>&1 || err "Missing dependency: $cmd"
done

echo 'int main(){}' | gcc -m32 -x c - -o /dev/null 2>/dev/null || {
    warn "Missing 32-bit compilation support. Install:"
    warn "  Ubuntu/Debian: sudo apt install gcc-multilib g++-multilib libc6-dev-i386"
    warn "  Fedora:        sudo dnf install glibc-devel.i686 libstdc++-devel.i686"
    err "Cannot compile 32-bit programs"
}

info "=== Building Linux x86 (32-bit) bgfx (with Vulkan patches) ==="
info "Output: $LIB_OUT"

if [ ! -d "$BUILD_DIR/bgfx" ]; then
    info "Source not found. Run build_linux_x64.sh first to clone and patch."
    info "Or manually:"
    info "  cd $BUILD_DIR"
    info "  git clone --depth 1 https://github.com/bkaradzic/bgfx.git"
    info "  git clone --depth 1 https://github.com/bkaradzic/bx.git"
    info "  git clone --depth 1 https://github.com/bkaradzic/bimg.git"
    err "Missing source"
fi

BGFX_H="$BUILD_DIR/bgfx/include/bgfx/bgfx.h"
if ! grep -q 'vkInstance' "$BGFX_H" 2>/dev/null; then
    err "Patches not applied. Run build_linux_x64.sh first to apply patches."
fi
info "Patches confirmed"

info "Generating build files..."
BX_DIR="$BUILD_DIR/bx"
cd "$BUILD_DIR/bgfx"

OS=$(uname -s)
case "$OS" in
    Linux)  GENIE="$BX_DIR/tools/bin/linux/genie" ;;
    Darwin) GENIE="$BX_DIR/tools/bin/darwin/genie" ;;
    *)      err "Unsupported OS: $OS" ;;
esac

"$GENIE" --gcc=linux-gcc gmake
cd .build/projects/gmake-linux-gcc

info "Building bgfx, bx, bimg (x86)..."
make bgfx bx bimg config=release64 \
    CC="gcc -m32" CXX="g++ -m32" -j$(nproc) \
    CFLAGS="-m32" CXXFLAGS="-m32"

mkdir -p "$LIB_OUT"
BUILD_OUT="$BUILD_DIR/bgfx/.build/linux64_gcc/bin"
cp -v "$BUILD_OUT/libbgfxRelease.a" "$LIB_OUT/libbgfx.a"
cp -v "$BUILD_OUT/libbxRelease.a"   "$LIB_OUT/libbx.a"
cp -v "$BUILD_OUT/libbimgRelease.a" "$LIB_OUT/libbimg.a"

info "Building shaderc (x86)..."
make shaderc config=release64 \
    CC="gcc -m32" CXX="g++ -m32" -j$(nproc) \
    CFLAGS="-m32" CXXFLAGS="-m32"
cp -v "$BUILD_DIR/bgfx/.build/linux64_gcc/bin/shadercRelease" "$SCRIPT_DIR/../tools/shaderc" 2>/dev/null || true

echo ""
info "=================================================================="
info "Linux x86 (32-bit) bgfx build complete!"
info "Output: $LIB_OUT"
ls -lh "$LIB_OUT/"
info "=================================================================="
