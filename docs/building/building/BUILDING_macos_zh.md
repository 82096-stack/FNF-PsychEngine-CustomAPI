# macOS 编译指南

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Xcode Command Line Tools（`xcode-select --install`）
- [Haxe 4.3.6+](https://haxe.org/download)
- Git

## 快速开始

```bash
# 1. 安装 Haxe 依赖
cd setup && ./unix.sh

# 2. 编译 bgfx（原版，macOS 无需 Vulkan 补丁）
cd ../libs/hxbgfx && ./build_macos.sh

# 3. 编译项目
cd ../.. && haxelib run lime build mac
```

## 详细步骤

### 1. 安装 Haxe 依赖

```bash
cd setup
./unix.sh
```

这会安装所有需要的 haxelib 包（lime, openfl, flixel, hxcpp 等）。

### 2. 编译 bgfx

macOS 使用 Metal，不需要 Vulkan 补丁。编译脚本使用原版 bgfx。

```bash
cd libs/hxbgfx
./build_macos.sh          # 编译 arm64 + x64（默认）
./build_macos.sh arm64    # 仅编译 arm64
./build_macos.sh x64      # 仅编译 x64
```

脚本会自动：
- 克隆 bgfx/bx/bimg 源码
- 编译为静态库
- 输出到 `lib/macos/`

### 3. 编译运行

```bash
haxelib run lime build mac
haxelib run lime test mac
```

## 图形 API 支持

项目通过 bgfx 支持以下图形 API，可在游戏内运行时切换：

| API | 可用性 |
|-----|--------|
| Metal | ✅ 默认推荐 |
| OpenGL | ✅ |

## 上采样器支持

| 上采样器 | macOS 可用 |
|----------|-----------|
| DirectEnlarge | ✅ |
| FSR 1 | ✅ |
| FSR 2 | ❌ (仅 D3D12) |
| FSR 3.1 | ❌ (仅 D3D12) |
| MetalFX | ✅ (Spatial + Temporal) |
| NIS | ✅ |
| DLSS | ❌ (仅 Windows/Linux) |
| XeSS | ❌ (仅 Windows/Linux) |

## 故障排除

**编译失败："xcrun: error: invalid active developer path"**
```bash
xcode-select --install
```

**haxelib 找不到包**
```bash
haxelib setup ~/haxelib
```

**MetalFX 不可用**
- 需要 macOS 13.0 (Ventura) 或更高版本
- 需要 Apple Silicon (M1/M2/M3/M4) 或支持的 Intel Mac
