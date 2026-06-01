#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HXBGFX_DIR="$(dirname "$SCRIPT_DIR")"
LIBS_DIR="${HXBGFX_DIR}/lib"
BUILD_DIR="${HXBGFX_DIR}/.build"
PLATFORM="${1:-$(uname -s | tr '[:upper:]' '[:lower:]')}"

case "$PLATFORM" in
	macos|darwin)   PLATFORM_DIR="macos" ;;
	linux)          PLATFORM_DIR="linux" ;;
	windows|mingw*) PLATFORM_DIR="windows" ;;
	*) echo "Unknown platform: $PLATFORM"; exit 1 ;;
esac

OUTPUT_DIR="${LIBS_DIR}/${PLATFORM_DIR}"
echo "=== Building bgfx for ${PLATFORM_DIR} ==="
echo "Output: ${OUTPUT_DIR}"

# Clone bgfx/bx/bimg (default branch, shallow)
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

for repo in bgfx bx bimg; do
	if [ ! -d "${repo}" ]; then
		echo "Cloning ${repo}..."
		git clone --depth 1 "https://github.com/bkaradzic/${repo}.git" "${repo}"
	else
		echo "${repo} already exists, skipping clone"
	fi
done

# Create symlinks for includes
ln -sfn "${BUILD_DIR}/bgfx" "${HXBGFX_DIR}/bgfx"
ln -sfn "${BUILD_DIR}/bx"   "${HXBGFX_DIR}/bx"
ln -sfn "${BUILD_DIR}/bimg" "${HXBGFX_DIR}/bimg"

# Build
cd "${BUILD_DIR}/bgfx"

case "$PLATFORM_DIR" in
	macos)
		echo "Building for macOS arm64..."
		make -C .build/projects/gmake2-genie -j$(sysctl -n hw.ncpu) config=release64 2>&1
		mkdir -p "${OUTPUT_DIR}"
		cp .build/osx-arm64/bin/libbgfxRelease.a  "${OUTPUT_DIR}/libbgfx.a"
		cp .build/osx-arm64/bin/libbxRelease.a     "${OUTPUT_DIR}/libbx.a"
		cp .build/osx-arm64/bin/libbimgRelease.a   "${OUTPUT_DIR}/libbimg.a"
		;;
	linux)
		echo "Building for Linux x64..."
		make -C .build/projects/gmake2-genie -j$(nproc) config=release64 2>&1
		mkdir -p "${OUTPUT_DIR}"
		cp .build/linux64_gcc/bin/libbgfxRelease.a  "${OUTPUT_DIR}/libbgfx.a"
		cp .build/linux64_gcc/bin/libbxRelease.a     "${OUTPUT_DIR}/libbx.a"
		cp .build/linux64_gcc/bin/libbimgRelease.a   "${OUTPUT_DIR}/libbimg.a"
		;;
	windows)
		echo "Windows: build bgfx .sln with VS2022, then copy bgfx.lib/bx.lib/bimg.lib to ${OUTPUT_DIR}"
		;;
esac

echo "=== Done ==="
ls -la "${OUTPUT_DIR}/"
