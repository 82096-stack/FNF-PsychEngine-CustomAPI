# Linux Build Guide

## Requirements

- Ubuntu 20.04+ / Debian 11+ / Fedora 36+ (or similar)
- GCC 9+ or Clang 12+
- [Haxe 4.3.6+](https://haxe.org/download)
- Git

## Quick Start

```bash
# 1. Install system dependencies (Ubuntu/Debian)
sudo apt update
sudo apt install -y build-essential git libx11-dev libxext-dev \
    libvulkan-dev libgl-dev libsdl2-dev libvlc-dev

# 2. Install Haxe dependencies

cd setup && ./unix.sh
# 3. Build bgfx (with Vulkan patches)
cd ../libs/hxbgfx
./build_linux_x64.sh       # 64-bit
./build_linux_x86.sh       # 32-bit (requires gcc-multilib)


# 4. Build the project
cd .. && haxelib run lime build linux
```

## Detailed Steps

### 1. Install System Dependencies

**Ubuntu / Debian:**
```bash
sudo apt update
sudo apt install -y build-essential git libx11-dev libxext-dev \
    libvulkan-dev libgl-dev libsdl2-dev libvlc-dev
```

**Fedora:**
```bash
sudo dnf install -y gcc-c++ git libX11-devel libXext-devel \
    vulkan-devel mesa-libGL-devel SDL2-devel vlc-devel
```

**Arch Linux:**
```bash
sudo pacman -S --needed base-devel git libx11 libxext \
    vulkan-devel libgl sdl2 vlc
```

### 2. Install Haxe Dependencies

```bash
cd setup
./unix.sh
```

### 3. Build bgfx

The project uses a patched version of bgfx that exposes Vulkan handles for DLSS/XeSS.

```bash
cd libs/hxbgfx
./build_linux_x64.sh       # 64-bit
```

The script will automatically:
- Clone bgfx/bx/bimg source
- Apply 5 Vulkan patches
- Compile static libraries + shaderc
- Output to `lib/linux/x64/`

**32-bit build (optional):**
```bash
sudo apt install gcc-multilib g++-multilib libc6-dev-i386
./build_linux_x86.sh
```


### 4. Build & Run

```bash
haxelib run lime build linux
haxelib run lime test linux
```

## Graphics API Support

Runtime-switchable via bgfx:

| API | Availability |
|-----|-------------|
| Vulkan | ✅ Default recommended |
| OpenGL | ✅ |

## Upscaler Support

| Upscaler | Available on Linux |
|----------|-------------------|
| DirectEnlarge | ✅ |
| FSR 1 | ✅ |
| FSR 2 | ❌ (D3D12 only) |
| FSR 3.1 | ❌ (D3D12 only) |
| DLSS | ✅ (Vulkan) |
| XeSS | ✅ (Vulkan) |
| NIS | ✅ |
| MetalFX | ❌ (macOS only) |

## Troubleshooting

**Can't compile 32-bit**
```bash
sudo apt install gcc-multilib g++-multilib libc6-dev-i386
```

**Vulkan init failed**
```bash
# Check Vulkan support
vulkaninfo | grep deviceName
# Install Vulkan drivers
sudo apt install mesa-vulkan-drivers
```

**SDL2 not found**
```bash
sudo apt install libsdl2-dev
```
