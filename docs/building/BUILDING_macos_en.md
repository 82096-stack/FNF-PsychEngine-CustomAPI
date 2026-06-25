# macOS Build Guide

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)
- [Haxe 4.3.6+](https://haxe.org/download)
- Git

## Quick Start

```bash
# 1. Install Haxe dependencies

cd setup && ./unix.sh
# 2. Build bgfx (stock, no Vulkan patches needed on macOS)
cd ../libs/hxbgfx && ./build_macos.sh

# 3. Build the project
cd ../.. && haxelib run lime build mac
```

## Detailed Steps

### 1. Install Haxe Dependencies

```bash
cd setup
./unix.sh
```

This installs all required haxelib packages (lime, openfl, flixel, hxcpp, etc.).

### 2. Build bgfx

macOS uses Metal, not Vulkan. The build script compiles stock bgfx without patches.

```bash
cd libs/hxbgfx
./build_macos.sh          # Build arm64 + x64 (default)
./build_macos.sh arm64    # Build arm64 only
./build_macos.sh x64      # Build x64 only
```

The script will automatically:
- Clone bgfx/bx/bimg source
- Compile static libraries
- Output to `lib/macos/`

### 3. Build & Run

```bash
haxelib run lime build mac
haxelib run lime test mac
```

## Graphics API Support

Runtime-switchable via bgfx:

| API | Availability |
|-----|-------------|
| Metal | ✅ Default recommended |
| OpenGL | ✅ |

## Upscaler Support

| Upscaler | Available on macOS |
|----------|-------------------|
| DirectEnlarge | ✅ |
| FSR 1 | ✅ |
| FSR 2 | ❌ (D3D12 only) |
| FSR 3.1 | ❌ (D3D12 only) |
| MetalFX | ✅ (Spatial + Temporal) |
| NIS | ✅ |
| DLSS | ❌ (Windows/Linux only) |
| XeSS | ❌ (Windows/Linux only) |

## Troubleshooting

**"xcrun: error: invalid active developer path"**
```bash
xcode-select --install
```

**haxelib can't find packages**
```bash
haxelib setup ~/haxelib
```

**MetalFX unavailable**
- Requires macOS 13.0 (Ventura) or later
- Requires Apple Silicon (M1/M2/M3/M4) or supported Intel Mac
