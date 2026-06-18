#!/usr/bin/env bash
# ───────────────────────────────────────────────────────────────────
# build_ffmpeg_libs.sh — Compile FFmpeg static libraries for Psych Engine
#
# This script downloads and builds FFmpeg from source with a minimal
# configuration that includes only what we need:
#   - Demuxers:  mov (MP4), matroska (WebM)
#   - Decoders:  h264, vp9
#   - Parsers:   h264, vp9
#   - Protocols: file
#   - Pixel formats: RGBA output via swscale
#
# Output:
#   libs/ffmpeg/lib/<platform>/*.a (or *.lib on Windows)
#   libs/ffmpeg/include/            (FFmpeg public headers)
#
# Usage:
#   ./build_ffmpeg_libs.sh          # Build for current platform
#   ./build_ffmpeg_libs.sh clean    # Remove build artifacts
#   ./build_ffmpeg_libs.sh all      # Build for all platforms (cross-compile)
#
# Requirements:
#   - git, make, pkg-config
#   - C/C++ compiler (gcc/clang on Unix, MSVC or MinGW on Windows)
#   - nasm or yasm (for assembly optimizations; optional)
#   - For cross-compilation: appropriate cross-compiler toolchain
# ───────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FFMPEG_DIR="$(dirname "$SCRIPT_DIR")"
LIBS_DIR="$FFMPEG_DIR/lib"
INCLUDE_DIR="$FFMPEG_DIR/include"
BUILD_DIR="$FFMPEG_DIR/build"
FFMPEG_SRC="$BUILD_DIR/ffmpeg-src"
FFMPEG_VERSION="6.1.1"  # Stable release

# ── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Detect platform ───────────────────────────────────────────────
detect_platform() {
	case "$(uname -s)" in
		Darwin)  echo "macos" ;;
		Linux)   echo "linux" ;;
		MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
		*)       echo "unknown" ;;
	esac
}

PLATFORM="${1:-$(detect_platform)}"

# ── Common FFmpeg configure flags ─────────────────────────────────
# Minimal build: only what we need for video playback
COMMON_CONFIGURE_FLAGS=(
	--prefix="${BUILD_DIR}/install-${PLATFORM}"

	# Disable everything first
	--disable-everything
	--disable-programs
	--disable-doc
	--disable-avdevice
	--disable-postproc
	--disable-avfilter
	--disable-network
	--disable-bsfs
	--disable-muxers
	--disable-encoders
	--disable-filters
	--disable-bzlib
	--disable-lzma
	--disable-xlib
	--disable-iconv

	# Enable what we need
	--enable-decoder=h264,vp9
	--enable-demuxer=mov,matroska
	--enable-parser=h264,vp9
	--enable-protocol=file

	# Pixel format conversion
	--enable-swscale
	--enable-swresample

	# Minimal, no external libs
	--enable-small
	--enable-static
	--disable-shared

	# Threading
	--enable-pthreads

	# Pic for static linking
	--enable-pic
)

# ── Platform-specific configure flags ─────────────────────────────
platform_flags() {
	case "$1" in
		macos)
			printf '%s\n' \
				"--extra-ldflags=-framework CoreFoundation -framework CoreMedia -framework CoreVideo -framework VideoToolbox -framework Security -framework AudioToolbox" \
				"--enable-videotoolbox"
			;;
		windows)
			# When cross-compiling from Linux/macOS with MinGW, add:
			# --cross-prefix=x86_64-w64-mingw32- --target-os=mingw32 --arch=x86_64
			printf '%s\n' \
				"--enable-dxva2" \
				"--enable-d3d11va"
			;;
		linux)
			printf '%s\n' \
				"--enable-vaapi" \
				"--enable-vdpau"
			;;
	esac
}

# ── Download FFmpeg source ────────────────────────────────────────
download_ffmpeg() {
	mkdir -p "$BUILD_DIR"

	if [ -d "$FFMPEG_SRC" ]; then
		info "FFmpeg source already exists at $FFMPEG_SRC"
		info "To re-download, run: $0 clean"
		return
	fi

	info "Downloading FFmpeg ${FFMPEG_VERSION}..."
	cd "$BUILD_DIR"

	# Try GitHub mirror first, fall back to ffmpeg.org
	if ! curl -fsSL "https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n${FFMPEG_VERSION}.tar.gz" -o ffmpeg.tar.gz; then
		info "GitHub mirror failed, trying ffmpeg.org..."
		curl -fsSL "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz" -o ffmpeg.tar.gz
	fi

	tar xzf ffmpeg.tar.gz
	rm ffmpeg.tar.gz

	# Rename to standard name
	local extracted
	extracted=$(find . -maxdepth 1 -type d -name "ffmpeg*" ! -name "ffmpeg-src" | head -1)
	if [ -n "$extracted" ] && [ "$extracted" != "./ffmpeg-src" ]; then
		mv "$extracted" ffmpeg-src
	fi

	info "FFmpeg source downloaded to $FFMPEG_SRC"
}

# ── Build for a single platform ────────────────────────────────────
build_for_platform() {
	local plat="$1"
	info "Building FFmpeg for: $plat"

	mkdir -p "${BUILD_DIR}/build-${plat}"

	cd "${BUILD_DIR}/build-${plat}"

	# Run configure
	info "Configuring FFmpeg for $plat..."
	local plat_flags=()
	local saved_ifs="$IFS"
	IFS=$'\n'
	for flag in $(platform_flags "$plat"); do
		plat_flags+=("$flag")
	done
	IFS="$saved_ifs"
	local configure_args=(
		"${COMMON_CONFIGURE_FLAGS[@]}"
		"${plat_flags[@]}"
	)

	"${FFMPEG_SRC}/configure" "${configure_args[@]}"

	# Build
	info "Compiling FFmpeg for $plat..."
	make -j"$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"

	# Install to platform-specific prefix
	info "Installing FFmpeg for $plat..."
	make install

	# Copy libraries
	local plat_lib_dir="$LIBS_DIR/$plat"
	if [ "$plat" = "windows" ]; then
		plat_lib_dir="${plat_lib_dir}/x64"
	fi
	mkdir -p "$plat_lib_dir"

	local install_dir="${BUILD_DIR}/install-${plat}"
	if [ -d "${install_dir}/lib" ]; then
		cp -v "${install_dir}/lib"/libavcodec.* "$plat_lib_dir/" 2>/dev/null || true
		cp -v "${install_dir}/lib"/libavformat.* "$plat_lib_dir/" 2>/dev/null || true
		cp -v "${install_dir}/lib"/libavutil.* "$plat_lib_dir/" 2>/dev/null || true
		cp -v "${install_dir}/lib"/libswscale.* "$plat_lib_dir/" 2>/dev/null || true
		cp -v "${install_dir}/lib"/libswresample.* "$plat_lib_dir/" 2>/dev/null || true
	fi

	# On Windows with MSVC, libs might be in a different location
	if [ "$plat" = "windows" ] && [ -d "${install_dir}/bin" ]; then
		# MSVC puts .lib files alongside .dll in bin/
		cp -v "${install_dir}/bin"/*.lib "$plat_lib_dir/" 2>/dev/null || true
	fi

	# Copy headers (only once — they're platform-independent)
	if [ ! -d "$INCLUDE_DIR/libavcodec" ]; then
		info "Copying FFmpeg headers to $INCLUDE_DIR"
		mkdir -p "$INCLUDE_DIR"
		cp -r "${install_dir}/include/"* "$INCLUDE_DIR/"
	fi

	info "FFmpeg build for $plat complete!"
	info "Libraries installed to: $plat_lib_dir"
}

# ── Clean ─────────────────────────────────────────────────────────
clean() {
	info "Cleaning FFmpeg build artifacts..."
	rm -rf "$BUILD_DIR"
	rm -rf "$INCLUDE_DIR"
	rm -rf "$LIBS_DIR/windows" "$LIBS_DIR/linux" "$LIBS_DIR/macos"
	info "Clean complete."
}

# ── Print info ────────────────────────────────────────────────────
print_info() {
	echo ""
	echo "============================================"
	echo "  Psych Engine — FFmpeg library builder"
	echo "============================================"
	echo ""
	echo "Platform detected: $PLATFORM"
	echo ""
	echo "Usage:"
	echo "  $0              Build for current platform"
	echo "  $0 macos        Build for macOS"
	echo "  $0 linux        Build for Linux"
	echo "  $0 windows      Build for Windows (requires cross-compiler)"
	echo "  $0 all          Build for all platforms"
	echo "  $0 clean        Remove build artifacts"
	echo ""
	echo "Output directories:"
	echo "  Libraries:   $LIBS_DIR/<platform>/"
	echo "  Headers:     $INCLUDE_DIR/"
	echo "  Build temp:  $BUILD_DIR/"
	echo ""
	echo "After building:"
	echo "  1. Add 'FFMPEG_LOCAL_INCLUDE' define to Project.xml"
	echo "  2. Rebuild the Haxe project"
	echo ""
}

# ── Main ──────────────────────────────────────────────────────────
case "$PLATFORM" in
	clean)
		clean
		;;
	help|--help|-h)
		print_info
		;;
	all)
		download_ffmpeg
		build_for_platform "macos"
		build_for_platform "linux"
		build_for_platform "windows"
		;;
	macos|linux|windows)
		download_ffmpeg
		build_for_platform "$PLATFORM"
		;;
	*)
		err "Unknown platform: $PLATFORM"
		print_info
		exit 1
		;;
esac
