#!/bin/bash
# ================================================================
# build_linux_x64.sh — Build Linux x64 bgfx (with Vulkan patches)
#
# Usage: ./build_linux_x64.sh
# Output: libs/hxbgfx/lib/linux/x64/libbgfx.a, libbx.a, libbimg.a
# ================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
LIB_OUT="$SCRIPT_DIR/lib/linux/x64"

for cmd in git make gcc g++; do
    command -v "$cmd" >/dev/null 2>&1 || err "Missing dependency: $cmd"
done

info "=== Building Linux x64 bgfx (with Vulkan patches) ==="

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

# ==== Apply patches ====
info "Applying Vulkan patches..."

BGFX_H="$BUILD_DIR/bgfx/include/bgfx/bgfx.h"
BGFX_C99="$BUILD_DIR/bgfx/include/bgfx/c99/bgfx.h"
RENDERER_VK="$BUILD_DIR/bgfx/src/renderer_vk.cpp"

if ! grep -q 'vkInstance' "$BGFX_H" 2>/dev/null; then
    info "Patch 1/5: bgfx.h InternalData"
    sed -i '/void\* context;.*GL context, or D3D device/a\
            void* vkInstance;           \/\/ VkInstance (Vulkan only, NULL otherwise)\
            void* vkPhysicalDevice;     \/\/ VkPhysicalDevice (Vulkan only)
' "$BGFX_H"
fi

if ! grep -q 'vkInstance' "$BGFX_C99" 2>/dev/null; then
    info "Patch 2/5: c99/bgfx.h InternalData"
    sed -i '/void\*[[:space:]]*context.*GL context, or D3D device/a\
    void*                vkInstance;         /** VkInstance (Vulkan only) */\
    void*                vkPhysicalDevice;   /** VkPhysicalDevice (Vulkan only) */
' "$BGFX_C99"
fi

if grep -q 'return 0;' "$RENDERER_VK" 2>/dev/null; then
    info "Patch 3/5: renderer_vk.cpp getInternal"
    sed -i 's|uintptr_t getInternal(TextureHandle /\*_handle\*/) override|uintptr_t getInternal(TextureHandle _handle) override|' "$RENDERER_VK"
    sed -i '/uintptr_t getInternal(TextureHandle _handle) override/,/^[[:space:]]*}/{
        s/return 0;/return (uintptr_t)(void*)m_textures[_handle.idx].m_textureImage;/
    }' "$RENDERER_VK"
fi

if ! grep -q 'vkInstance.*m_instance' "$RENDERER_VK" 2>/dev/null; then
    info "Patch 4/5: renderer_vk.cpp InternalData init"
    LINE=$(grep -n 'errorState = ErrorState::DeviceCreated' "$RENDERER_VK" | head -1 | cut -d: -f1)
    if [ -n "$LINE" ]; then
        sed -i "${LINE}a\\
\\
                {   // PATCH: Expose Vulkan handles for DLSS/XeSS\\
                    bgfx::InternalData* d = const_cast<bgfx::InternalData*>(bgfx::getInternalData());\\
                    if (d) { d->vkInstance = (void*)m_instance; d->vkPhysicalDevice = (void*)m_physicalDevice; }\\
                }" "$RENDERER_VK"
    fi
fi

if [ -f "$BUILD_DIR/bgfx/src/glcontext_egl.cpp" ]; then
    info "Patch 5/5: glcontext_egl.cpp"
    sed -i 's/(EGLNativeWindowType) m_eglWindow/(EGLNativeWindowType)(uintptr_t) m_eglWindow/' "$BUILD_DIR/bgfx/src/glcontext_egl.cpp"
    sed -i 's/(EGLNativeWindowType)_nwh/(EGLNativeWindowType)(uintptr_t)_nwh/' "$BUILD_DIR/bgfx/src/glcontext_egl.cpp"
fi

info "All patches applied"

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

info "Building bgfx, bx, bimg (x64)..."
make bgfx bx bimg config=release64 -j$(nproc)

mkdir -p "$LIB_OUT"
BUILD_OUT="$BUILD_DIR/bgfx/.build/linux64_gcc/bin"
cp -v "$BUILD_OUT/libbgfxRelease.a" "$LIB_OUT/libbgfx.a"
cp -v "$BUILD_OUT/libbxRelease.a"   "$LIB_OUT/libbx.a"
cp -v "$BUILD_OUT/libbimgRelease.a" "$LIB_OUT/libbimg.a"

info "Building shaderc..."
make shaderc config=release64 -j$(nproc 2>/dev/null || echo 4)
cp -v "$BUILD_DIR/bgfx/.build/linux64_gcc/bin/shadercRelease" "$SCRIPT_DIR/../tools/shaderc" 2>/dev/null || true

echo ""
info "=================================================================="
info "Linux x64 bgfx build complete!"
info "Output: $LIB_OUT"
ls -lh "$LIB_OUT/"
info "=================================================================="
