#!/bin/bash
# ───────────────────────────────────────────────────────────────────
# build_bgfx_libs.sh — Build bgfx static libraries for Psych Engine
#
# Clones bgfx/bx/bimg, generates makefiles via GENie, and builds
# static libraries for the target platform.
#
# Output:
#   libs/hxbgfx/lib/<platform>/libbgfx.a, libbx.a, libbimg.a
#
# Usage:
#   ./build_bgfx_libs.sh         # Build for current platform
#   ./build_bgfx_libs.sh clean   # Remove source and build artifacts
# ───────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HXBGFX_DIR="$(dirname "$SCRIPT_DIR")"
LIBS_DIR="${HXBGFX_DIR}/lib"
BUILD_DIR="${HXBGFX_DIR}/.build"

# ── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Detect platform ───────────────────────────────────────────────
detect_platform() {
	case "$(uname -s)" in
		Darwin)
			# Detect architecture
			if [ "$(uname -m)" = "arm64" ]; then
				echo "macos-arm64"
			else
				echo "macos-x64"
			fi
			;;
		Linux)   echo "linux" ;;
		MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
		*)       echo "unknown" ;;
	esac
}

PLATFORM="${1:-$(detect_platform)}"

# ── Map platform to GENie and output settings ──────────────────────
case "$PLATFORM" in
	macos-arm64)
		GENIE_GCC="osx-arm64"
		OUTPUT_DIR="${LIBS_DIR}/macos"
		BUILD_OUTPUT_SUBDIR="osx-arm64"
		;;
	macos-x64)
		GENIE_GCC="osx-x64"
		OUTPUT_DIR="${LIBS_DIR}/macos"
		BUILD_OUTPUT_SUBDIR="osx-x64"
		;;
	macos)
		# Legacy: default to arm64
		GENIE_GCC="osx-arm64"
		OUTPUT_DIR="${LIBS_DIR}/macos"
		BUILD_OUTPUT_SUBDIR="osx-arm64"
		;;
	linux)
		GENIE_GCC="linux-gcc"
		OUTPUT_DIR="${LIBS_DIR}/linux/x64"
		BUILD_OUTPUT_SUBDIR="linux64_gcc"
		;;
	windows)
		GENIE_GCC="mingw-gcc"
		OUTPUT_DIR="${LIBS_DIR}/windows/x64"
		BUILD_OUTPUT_SUBDIR="win64_mingw-gcc"
		;;
	clean)
		info "Cleaning bgfx build artifacts and sources..."
		rm -rf "${BUILD_DIR}" "${LIBS_DIR}/windows" "${LIBS_DIR}/linux" "${LIBS_DIR}/macos"
		rm -f "${HXBGFX_DIR}/bgfx" "${HXBGFX_DIR}/bx" "${HXBGFX_DIR}/bimg"
		info "Clean complete."
		exit 0
		;;
	*)
		err "Unknown platform: $PLATFORM"
		echo ""
		echo "Usage:"
		echo "  $0                    Build for current platform"
		echo "  $0 macos-arm64        Build for macOS ARM64"
		echo "  $0 macos-x64          Build for macOS x64"
		echo "  $0 linux              Build for Linux (requires cross-compiler)"
		echo "  $0 windows            Build for Windows (requires MinGW)"
		echo "  $0 clean              Remove build artifacts"
		exit 1
		;;
esac

GENIE="${BUILD_DIR}/bx/tools/bin/darwin/genie"
BGFX_SRC="${BUILD_DIR}/bgfx"

# ── Clone sources ──────────────────────────────────────────────────
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

for repo in bgfx bx bimg; do
	if [ ! -d "${repo}/.git" ]; then
		info "Cloning ${repo}..."
		git clone --depth 1 "https://github.com/bkaradzic/${repo}.git" "${repo}"
	else
		info "${repo} already exists, skipping clone"
	fi
done

# ── Create symlinks for includes ───────────────────────────────────
ln -sfn "${BUILD_DIR}/bgfx" "${HXBGFX_DIR}/bgfx"
ln -sfn "${BUILD_DIR}/bx"   "${HXBGFX_DIR}/bx"
ln -sfn "${BUILD_DIR}/bimg" "${HXBGFX_DIR}/bimg"

# ── Generate build files ───────────────────────────────────────────
info "Generating build files with GENie (${GENIE_GCC})..."
cd "${BGFX_SRC}"
BX_DIR="${BUILD_DIR}/bx" "${GENIE}" --gcc="${GENIE_GCC}" gmake

PROJECT_DIR="${BGFX_SRC}/.build/projects/gmake-${GENIE_GCC}"

# ── Build ──────────────────────────────────────────────────────────
info "Building bgfx, bx, bimg..."
JOBS=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
make -C "${PROJECT_DIR}" -j"${JOBS}" bgfx bx bimg config=release64

# ── Copy to output ─────────────────────────────────────────────────
info "Copying libraries to ${OUTPUT_DIR}..."
mkdir -p "${OUTPUT_DIR}"
cp -v "${BGFX_SRC}/.build/${BUILD_OUTPUT_SUBDIR}/bin/libbgfxRelease.a" "${OUTPUT_DIR}/libbgfx.a"
cp -v "${BGFX_SRC}/.build/${BUILD_OUTPUT_SUBDIR}/bin/libbxRelease.a"    "${OUTPUT_DIR}/libbx.a"
cp -v "${BGFX_SRC}/.build/${BUILD_OUTPUT_SUBDIR}/bin/libbimgRelease.a"  "${OUTPUT_DIR}/libbimg.a"

info "bgfx build for ${PLATFORM} complete!"
info "Libraries installed to: ${OUTPUT_DIR}"
ls -la "${OUTPUT_DIR}/"
