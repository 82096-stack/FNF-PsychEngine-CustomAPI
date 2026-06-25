# Linux 编译指南

## 系统要求

- Ubuntu 20.04+ / Debian 11+ / Fedora 36+（或其他主流发行版）
- GCC 9+ 或 Clang 12+
- [Haxe 4.3.6+](https://haxe.org/download)
- Git

## 快速开始

```bash
# 1. 安装系统依赖（Ubuntu/Debian）
sudo apt update
sudo apt install -y build-essential git libx11-dev libxext-dev \
    libvulkan-dev libgl-dev libsdl2-dev libvlc-dev

# 2. 安装 Haxe 依赖
cd setup && ./unix.sh

# 3. 编译 bgfx（含 Vulkan 补丁）
cd ../libs/hxbgfx
./build_linux_x64.sh       # 64-bit
./build_linux_x86.sh       # 32-bit（需要 gcc-multilib）


# 4. 编译项目
cd .. && ### 4. 编译运行

```bash
haxelib run lime build linux
```

## 详细步骤

### 1. 安装系统依赖

**Ubuntu / Debian：**
```bash
sudo apt update
sudo apt install -y build-essential git libx11-dev libxext-dev \
    libvulkan-dev libgl-dev libsdl2-dev libvlc-dev
```

**Fedora：**
```bash
sudo dnf install -y gcc-c++ git libX11-devel libXext-devel \
    vulkan-devel mesa-libGL-devel SDL2-devel vlc-devel
```

**Arch Linux：**
```bash
sudo pacman -S --needed base-devel git libx11 libxext \
    vulkan-devel libgl sdl2 vlc
```

### 2. 安装 Haxe 依赖

```bash
cd setup
./unix.sh
```

### 3. 编译 bgfx

项目使用打过 Vulkan 补丁的 bgfx（支持 DLSS/XeSS 的 Vulkan 句柄暴露）。

```bash
cd libs/hxbgfx
./build_linux_x64.sh       # 64-bit
```

脚本会自动：
- 克隆 bgfx/bx/bimg 源码
- 打 5 个 Vulkan 补丁
- 编译静态库 + shaderc
- 输出到 `lib/linux/x64/`

**32 位编译（可选）：**
```bash
sudo apt install gcc-multilib g++-multilib libc6-dev-i386
./build_linux_x86.sh
```


### 4. 编译运行

```bash
haxelib run lime build linux
haxelib run lime test linux
```

## 图形 API 支持

项目通过 bgfx 支持以下图形 API，可在游戏内运行时切换：

| API | 可用性 |
|-----|--------|
| Vulkan | ✅ 默认推荐 |
| OpenGL | ✅ |

## 上采样器支持

| 上采样器 | Linux 可用 |
|----------|-----------|
| DirectEnlarge | ✅ |
| FSR 1 | ✅ |
| FSR 2 | ❌ (仅 D3D12) |
| FSR 3.1 | ❌ (仅 D3D12) |
| DLSS | ✅ (Vulkan) |
| XeSS | ✅ (Vulkan) |
| NIS | ✅ |
| MetalFX | ❌ (仅 macOS) |

## 故障排除

**无法编译 32 位程序**
```bash
sudo apt install gcc-multilib g++-multilib libc6-dev-i386
```

**Vulkan 初始化失败**
```bash
# 检查 Vulkan 支持
vulkaninfo | grep deviceName
# 安装 Vulkan 驱动
sudo apt install mesa-vulkan-drivers
```

**SDL2 找不到**
```bash
sudo apt install libsdl2-dev
```
