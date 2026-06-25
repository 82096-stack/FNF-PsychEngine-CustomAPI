#!/bin/bash
# ================================================================
# compile_fsr_shaders_linux.sh — Compile FSR 2/3.1 Shaders (Linux)
#
# Usage: ./tools/compile_fsr_shaders_linux.sh [vulkan|gl|all]
# Default: vulkan
# Output: libs/fsr2/shaders_bgfx/vulkan/*.bin  or  gl/*.bin
#
# Prerequisites: shaderc (from bgfx build or system)
# ================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SHADER_SRC="$PROJECT_DIR/libs/fsr2/src/shaders"
SHADER_OUT="$PROJECT_DIR/libs/fsr2/shaders_bgfx"
VARYING_DEF="$PROJECT_DIR/source/shaders/varying.def"
SHADERC="$SCRIPT_DIR/shaderc"

PLATFORM="${1:-vulkan}"
OK=0; FAIL=0

# Ensure shaderc is available
ensure_shaderc() {
    if [ -f "$SHADERC" ] && [ -x "$SHADERC" ]; then
        info "shaderc ready: $SHADERC"
        return
    fi

    # Try getting from bgfx build directory
    local bgfx_bin="$PROJECT_DIR/libs/hxbgfx/.build/bgfx/.build/linux64_gcc/bin/shadercRelease"
    if [ -f "$bgfx_bin" ]; then
        cp "$bgfx_bin" "$SHADERC"
        chmod +x "$SHADERC"
        info "Copied from bgfx build directory shaderc"
        return
    fi

    # Try building
    warn "shaderc not found, trying to build from bgfx source..."
    local bgfx_src="$PROJECT_DIR/libs/hxbgfx/.build/bgfx"
    if [ -d "$bgfx_src" ]; then
        local bx_dir="$PROJECT_DIR/libs/hxbgfx/.build/bx"
        cd "$bgfx_src"
        "$bx_dir/tools/bin/linux/genie" --gcc=linux-gcc gmake 2>/dev/null || \
        "$bx_dir/tools/bin/darwin/genie" --gcc=linux-gcc gmake 2>/dev/null
        cd ".build/projects/gmake-linux-gcc"
        make shaderc config=release64 -j$(nproc 2>/dev/null || echo 4) 2>&1 | tail -3
        cp "$bgfx_src/.build/linux64_gcc/bin/shadercRelease" "$SHADERC" 2>/dev/null
        chmod +x "$SHADERC"
        info "shaderc build complete"
        cd "$SCRIPT_DIR"
    else
        err "bgfx Source not found. Run first: libs/hxbgfx/build_linux_x64.sh"
    fi
}

compile_shader() {
    local shader="$1"
    local profile="$2"  # spirv, glsl
    local outdir="$SHADER_OUT/$profile"
    local name=$(basename "$shader" .hlsl)
    local out="$outdir/${name}.bin"

    mkdir -p "$outdir"
    echo "  $name.hlsl → $profile/${name}.bin"

    "$SHADERC" \
        -f "$shader" \
        -o "$out" \
        --platform linux \
        --type compute \
        --profile "$profile" \
        --varyingdef "$VARYING_DEF" \
        -i "$SHADER_SRC" \
        -i "$PROJECT_DIR/libs/fsr2/include" \
        -i "$PROJECT_DIR/libs/fsr2/include/internal" \
        --define "FFX_FSR2=1" \
        --define "FFX_GPU=1" \
        2>&1 && { OK=$((OK+1)); return 0; } || { warn "  $name Compilation failed (FFX framework header deps may need manual fix)"; FAIL=$((FAIL+1)); return 1; }
}

# Main
info "=== FSR 2/3.1 Shader Compilation (Linux) ==="
ensure_shaderc

if [ ! -d "$SHADER_SRC" ]; then
    err "Shader source directory not found: $SHADER_SRC"
fi

case "$PLATFORM" in
    vulkan|spirv)
        info "Compiling Vulkan (SPIR-V) shaders..."
        for shader in "$SHADER_SRC"/*.hlsl; do
            compile_shader "$shader" "spirv" || true
        done
        ;;
    gl|opengl|glsl)
        info "Compiling OpenGL (GLSL) shaders..."
        for shader in "$SHADER_SRC"/*.hlsl; do
            compile_shader "$shader" "140" || true  # GLSL 1.40
        done
        ;;
    all)
        info "Compiling Vulkan + OpenGL shaders..."
        for shader in "$SHADER_SRC"/*.hlsl; do
            compile_shader "$shader" "spirv" || true
            compile_shader "$shader" "140" || true
        done
        ;;
    *)
        err "Unknown platform: $PLATFORM (options: vulkan, gl, all)"
        ;;
esac

echo ""
info "================================================================"
info "FSR 2/3.1 Shader compilation complete!"
info "OK:  $OK  FAIL:  $FAIL"
info "Output:  $SHADER_OUT/$PLATFORM/"
ls -la "$SHADER_OUT/$PLATFORM/" 2>/dev/null | tail -5 || warn "No files generated"
info "================================================================"
info "Note: FFX framework shaders may need manual header dependency fixing."
info "If compilation fails, check #include paths in HLSL source."
