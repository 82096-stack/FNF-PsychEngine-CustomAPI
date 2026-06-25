#!/bin/bash
# ============================================================================
# compile_shaders.sh — Compile bgfx shaders from GLSL source to platform binaries
#
# Prerequisites:
#   - bgfx shaderc tool (download from https://github.com/bkaradzic/bgfx)
#     Place the shaderc binary in tools/ or add to PATH.
#
# Usage:
#   ./tools/compile_shaders.sh          # Compile for current platform
#   ./tools/compile_shaders.sh mac      # Compile for macOS (Metal)
#   ./tools/compile_shaders.sh windows  # Compile for Windows (D3D11)
#   ./tools/compile_shaders.sh linux    # Compile for Linux (Vulkan)
#   ./tools/compile_shaders.sh all      # Compile for all platforms
#
# Output:
#   assets/shaders/bgfx/  — platform-specific .bin files
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SHADER_SRC="$PROJECT_DIR/source/shaders"
SHADER_OUT="$PROJECT_DIR/assets/shaders/bgfx"
VARYING_DEF="$SHADER_SRC/varying.def"
SHADERC="$(dirname "$0")/../tools/shaderc"

# Detect platform
PLATFORM="${1:-auto}"
if [ "$PLATFORM" = "auto" ]; then
    case "$(uname -s)" in
        Darwin)  PLATFORM="mac" ;;
        Linux)   PLATFORM="linux" ;;
        MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
        *)       echo "Unknown platform. Usage: $0 [mac|windows|linux|all]"; exit 1 ;;
    esac
fi

# Check shaderc
if ! command -v "$SHADERC" &> /dev/null; then
    # Try common locations
    for candidate in "$SCRIPT_DIR/shaderc" "$SCRIPT_DIR/bgfx/shaderc" \
                     "$PROJECT_DIR/../bgfx/.build/osx-x64/bin/shadercRelease"; do
        if [ -x "$candidate" ]; then
            SHADERC="$candidate"
            break
        fi
    done
fi

if ! command -v "$SHADERC" &> /dev/null; then
    echo "================================================================"
    echo "  shaderc not found!"
    echo ""
    echo "  Download bgfx and build shaderc:"
    echo "    git clone https://github.com/bkaradzic/bgfx.git"
    echo "    cd bgfx && make shaderc"
    echo ""
    echo "  Or download prebuilt from:"
    echo "    https://github.com/bkaradzic/bgfx/releases"
    echo ""
    echo "  Place shaderc in tools/ or add to PATH."
    echo "================================================================"
    exit 1
fi

echo "Using shaderc: $SHADERC"
echo "Platform: $PLATFORM"

# Resolve platform-specific parameters
resolve_profile() {
    case "$1" in
        mac)
            echo "osx"           # platform
            echo "metal"         # profile (vertex/fragment use same)
            echo "--platform osx -p metal"
            ;;
        windows)
            echo "windows"
            echo "s_5_0"         # D3D11 SM 5.0
            echo "--platform windows -p s_5_0"
            ;;
        linux)
            echo "linux"
            echo "spirv"         # Vulkan SPIR-V
            echo "--platform linux -p spirv"
            ;;
    esac
}

# Create output directory
mkdir -p "$SHADER_OUT"

# Generate varying.def if not exists
if [ ! -f "$VARYING_DEF" ]; then
    cat > "$VARYING_DEF" << 'VARYINGEOF'
vec2 v_texcoord0 : TEXCOORD0 = vec2(0.0, 0.0);

vec2 a_position  : POSITION;
vec2 a_texcoord0 : TEXCOORD0;
VARYINGEOF
    echo "Created varying.def"
fi

# ============================================================================
# Compile function
# ============================================================================
compile_shader() {
    local src="$1"
    local type="$2"
    local platform="$3"
    local profile="$4"
    local extra="$5"

    local name="$(basename "$src")"
    local out="$SHADER_OUT/${name}.bin"

    echo "  Compiling $name ($type, $platform/$profile)..."

    # Build include path: bgfx src directory
    local bgfx_include=""
    for dir in "$PROJECT_DIR/libs/hxbgfx/.build/bgfx/src" \
               "$PROJECT_DIR/../bgfx/src" \
               "/usr/local/include/bgfx"; do
        if [ -d "$dir" ]; then
            bgfx_include="$dir"
            break
        fi
    done

    # If bgfx include not found, try without (shaderc may have built-in paths)
    local include_flags=""
    if [ -n "$bgfx_include" ]; then
        include_flags="-i $bgfx_include"
    fi

    $SHADERC \
        -f "$src" \
        -o "$out" \
        --type "$type" \
        --platform "$platform" \
        -p "$profile" \
        --varyingdef "$VARYING_DEF" \
        $include_flags \
        $extra \
        --verbose 2>&1 | head -5

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "  ERROR: Failed to compile $name"
        return 1
    fi
    echo "  -> $out"
}

# ============================================================================
# Platform-specific shader compilation
# ============================================================================
compile_for_platform() {
    local plat="$1"
    local platform_id=$(resolve_profile "$plat" | sed -n '1p')
    local profile=$(resolve_profile "$plat" | sed -n '2p')
    local shaderc_flags=$(resolve_profile "$plat" | sed -n '3p')
    local extra=""

    # Metal: vertex and fragment use same profile
    # D3D11: vertex=vs_5_0, fragment=ps_5_0
    # Vulkan: both use spirv

    echo ""
    echo "=== Compiling for $plat ==="

    for src in "$SHADER_SRC"/*.vert "$SHADER_SRC"/*.frag; do
        [ -f "$src" ] || continue
        local name="$(basename "$src")"
        local ext="${name##*.}"
        local type=""

        case "$ext" in
            vert) type="vertex" ;;
            frag) type="fragment" ;;
            *) continue ;;
        esac

        # Handle platform-specific profile names
        local plat_profile="$profile"
        case "$plat" in
            windows)
                case "$ext" in
                    vert) plat_profile="vs_5_0" ;;
                    frag) plat_profile="ps_5_0" ;;
                esac
                ;;
        esac

        compile_shader "$src" "$type" "$platform_id" "$plat_profile" "$extra" || true
    done
}

# ============================================================================
# Main
# ============================================================================
if [ "$PLATFORM" = "all" ]; then
    compile_for_platform "mac"
    compile_for_platform "windows"
    compile_for_platform "linux"
else
    compile_for_platform "$PLATFORM"
fi

echo ""
echo "Done! Compiled shaders are in: $SHADER_OUT"
