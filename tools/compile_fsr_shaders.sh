#!/bin/bash
# ================================================================
# compile_fsr_shaders.sh — Compile FSR 2/3.1 HLSL shaders to bgfx .bin
#
# NOTE: FSR 2/3.1 is D3D12 ONLY (AMD FidelityFX SDK 2.2 limitation).
# This compiles shaders for Windows D3D12. Vulkan is experimental.
#
# Usage: ./tools/compile_fsr_shaders.sh [dx12|vulkan]
# ================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SHADER_SRC="$PROJECT_DIR/libs/fsr2/src/shaders"
SHADER_OUT="$PROJECT_DIR/libs/fsr2/shaders_bgfx"
VARYING_DEF="$PROJECT_DIR/source/shaders/varying.def"
SHADERC="$SCRIPT_DIR/shaderc"

PLATFORM="${1:-dx12}"

if [ ! -f "$SHADERC" ]; then
    echo "shaderc not found at $SHADERC"
    echo "Build it from bgfx source or download from https://github.com/bkaradzic/bgfx"
    exit 1
fi

if [ ! -d "$SHADER_SRC" ]; then
    echo "Shader source not found: $SHADER_SRC"
    exit 1
fi

compile_for() {
    local profile="$1" outdir="$SHADER_OUT/$profile"
    mkdir -p "$outdir"
    echo "=== Compiling for $profile ==="
    for shader in "$SHADER_SRC"/*.hlsl; do
        local name=$(basename "$shader" .hlsl)
        echo "  $name.hlsl -> $profile/${name}.bin"
        "$SHADERC" -f "$shader" -o "$outdir/${name}.bin" \
            --platform windows --type compute --profile "$profile" \
            --varyingdef "$VARYING_DEF" \
            -i "$SHADER_SRC" \
            -i "$PROJECT_DIR/libs/fsr2/include" \
            -i "$PROJECT_DIR/libs/fsr2/include/internal" \
            --define "FFX_FSR2=1" --define "FFX_GPU=1" \
            2>&1 || echo "  WARNING: $name failed"
    done
}

case "$PLATFORM" in
    dx12)    compile_for "dx12" ;;
    vulkan)  compile_for "spirv" ;;
    *)       echo "Usage: $0 [dx12|vulkan]"; exit 1 ;;
esac

echo "=== Done ==="
ls "$SHADER_OUT/$PLATFORM/" 2>/dev/null || echo "(no files)"
