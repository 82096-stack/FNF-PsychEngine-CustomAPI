# Windows Build Guide

## Requirements

- Windows 10/11 (x64)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) (with "Desktop development with C++" workload)
- [Haxe 4.3.6+](https://haxe.org/download)
- [Git for Windows](https://git-scm.com/download/win)

## Quick Start

```batch
REM 1. Install Haxe dependencies

cd setup
windows.bat
REM 2. Build bgfx (with Vulkan patches, 64-bit + 32-bit)
cd ..\libs\hxbgfx
build_windows.bat

REM 3. Compile FSR 2/3.1 shaders (optional)
cd ..\..\tools
compile_fsr_shaders_windows.bat all

REM 4. Build the project
cd ..
haxelib run lime build windows
```

## Detailed Steps

### 1. Install Visual Studio 2022

```batch
cd setup
windows-msvc.bat
```

Or manually download from https://visualstudio.microsoft.com/ and ensure "Desktop development with C++" is selected.

### 2. Install Haxe Dependencies

```batch
cd setup
windows.bat
```

### 3. Build bgfx

The project uses a patched version of bgfx that exposes Vulkan handles for DLSS/XeSS.

```batch
cd libs\hxbgfx
build_windows.bat
```

The script will automatically:
- Clone bgfx/bx/bimg source
- Apply Vulkan patches
- Compile 64-bit and 32-bit static libraries with Visual Studio
- Output to `lib/windows/x64/` and `lib/windows/x86/`

### 4. Compile FSR 2/3.1 Shaders (Optional)

FSR 1 shaders are pre-compiled. FSR 2/3.1 shaders need platform-specific compilation:

```batch
cd tools
compile_fsr_shaders_windows.bat all     REM All platforms
compile_fsr_shaders_windows.bat dx12    REM D3D12 only
compile_fsr_shaders_windows.bat dx11    REM D3D11 only
```

### 5. Build & Run

```batch
haxelib run lime build windows
haxelib run lime test windows
```

## Graphics API Support

Runtime-switchable via bgfx:

| API | Availability |
|-----|-------------|
| DirectX 12 | ✅ Default recommended |
| DirectX 11 | ✅ |
| Vulkan | ✅ |
| OpenGL | ✅ |

## Upscaler Support

| Upscaler | Available on Windows |
|----------|---------------------|
| DirectEnlarge | ✅ |
| FSR 1 | ✅ |
| FSR 2 | ✅ (D3D12 only) |
| FSR 3.1 | ✅ (D3D12 only) |
| DLSS | ✅ (D3D11/D3D12/Vulkan) |
| XeSS | ✅ (D3D11 Intel Arc only/D3D12/Vulkan) |
| NIS | ✅ |
| MetalFX | ❌ (macOS only) |

## Troubleshooting

**"Visual Studio not found"**
- Ensure VS 2022 with C++ workload is installed
- Run `setup/windows-msvc.bat`

**haxelib can't find packages**
```batch
haxelib setup %HOMEPATH%\haxelib
```

**Missing DLLs at runtime**
- DLSS DLL (`nvngx_dlss.dll`) is in `libs/dlss/lib/`
- XeSS DLL (`libxess.dll`) must be in runtime PATH
