# Windows 编译指南

## 系统要求

- Windows 10/11 (x64)
- [Visual Studio 2022](https://visualstudio.microsoft.com/)（含 "使用 C++ 的桌面开发" 工作负载）
- [Haxe 4.3.6+](https://haxe.org/download)
- [Git for Windows](https://git-scm.com/download/win)

## 快速开始

```batch
REM 1. 安装 Haxe 依赖
cd setup
windows.bat

REM 2. 编译 bgfx（含 Vulkan 补丁，64 位 + 32 位）
cd ..\libs\hxbgfx
build_windows.bat

REM 3. 编译 FSR 2/3.1 着色器（可选）
cd ..\..\tools
compile_fsr_shaders_windows.bat all

REM 4. 编译项目
cd ..
haxelib run lime build windows
```

## 详细步骤

### 1. 安装 Visual Studio 2022

```batch
cd setup
windows-msvc.bat
```

或手动从 https://visualstudio.microsoft.com/ 下载安装，确保勾选 "使用 C++ 的桌面开发"。

### 2. 安装 Haxe 依赖

```batch
cd setup
windows.bat
```

### 3. 编译 bgfx

项目使用打过 Vulkan 补丁的 bgfx（支持 DLSS/XeSS 的 Vulkan 句柄暴露）。

```batch
cd libs\hxbgfx
build_windows.bat
```

脚本会自动：
- 克隆 bgfx/bx/bimg 源码
- 打 Vulkan 补丁
- 用 Visual Studio 编译 64 位和 32 位静态库
- 输出到 `lib/windows/x64/` 和 `lib/windows/x86/`

### 4. 编译 FSR 2/3.1 着色器（可选）

FSR 1 着色器已预编译。FSR 2/3.1 需要在当前平台编译：

```batch
cd tools
compile_fsr_shaders_windows.bat all     REM 编译所有平台
compile_fsr_shaders_windows.bat dx12    REM 仅 D3D12
compile_fsr_shaders_windows.bat dx11    REM 仅 D3D11
```

### 5. 编译运行

```batch
haxelib run lime build windows
haxelib run lime test windows
```

## 图形 API 支持

项目通过 bgfx 支持以下图形 API，可在游戏内运行时切换：

| API | 可用性 |
|-----|--------|
| DirectX 12 | ✅ 默认推荐 |
| DirectX 11 | ✅ |
| Vulkan | ✅ |
| OpenGL | ✅ |

## 上采样器支持

| 上采样器 | Windows 可用 |
|----------|-------------|
| DirectEnlarge | ✅ |
| FSR 1 | ✅ |
| FSR 2 | ✅ (仅 D3D12) |
| FSR 3.1 | ✅ (仅 D3D12) |
| DLSS | ✅ (D3D11/D3D12/Vulkan) |
| XeSS | ✅ (D3D11 Intel Arc 限定/D3D12/Vulkan) |
| NIS | ✅ |
| MetalFX | ❌ (仅 macOS) |

## 故障排除

**"无法找到 Visual Studio"**
- 确保安装了 VS 2022 且包含 C++ 工作负载
- 运行 `setup/windows-msvc.bat`

**haxelib 找不到包**
```batch
haxelib setup %HOMEPATH%\haxelib
```

**编译时缺少 DLL**
- DLSS DLL (`nvngx_dlss.dll`) 在 `libs/dlss/lib/`
- XeSS DLL (`libxess.dll`) 在运行时 PATH 中
