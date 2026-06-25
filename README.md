![PsychEngineLogo](docs/img/Logo.png)

**Friday Night Funkin': Psych Engine** — A feature-rich FNF modding engine with multi-API rendering (Metal, Vulkan, DirectX 12/11, OpenGL), eight upscaling methods (DLSS, FSR 1/2/3.1, XeSS, MetalFX, NIS, Directly Enlarge), and hxvlc (libVLC) GPU-accelerated video playback.

> 🇨🇳 [中文文档 (Chinese Documentation)](README_CN.md)

---

# Build Guide

> 📘 **Detailed build instructions:：**
> - [macOS Build Guide](docs/building/BUILDING_macos_zh.md)
> - [Windows Build Guide](docs/building/BUILDING_windows_zh.md)
> - [Linux Build Guide](docs/building/BUILDING_linux_zh.md)
>
> - [macOS Build Guide (English)](docs/building/BUILDING_macos_en.md)
> - [Windows Build Guide (English)](docs/building/BUILDING_windows_en.md)
> - [Linux Build Guide (English)](docs/building/BUILDING_linux_en.md)

## Quick Start

```bash
git clone <repo-url>
cd FNF-PsychEngine-CustomAPI

# Install Haxe dependencies
./setup/unix.sh          # macOS / Linux
# setup\windows.bat      # Windows

# Build bgfx (with Vulkan patches)
cd libs/hxbgfx
./build_macos.sh          # macOS
# build_windows.bat       # Windows
# ./build_linux_x64.sh    # Linux

# Build the game
cd ../..
haxelib run lime build mac     # macOS
haxelib run lime build windows # Windows
haxelib run lime build linux   # Linux
```

> ⚠️ bgfx uses a patched version (exposes Vulkan handles for DLSS/XeSS). Do NOT replace with stock GitHub bgfx.
> The platform build scripts automatically clone source, apply patches, and compile.

```bash
haxelib run lime build mac       # macOS
haxelib run lime build windows   # Windows
haxelib run lime build linux     # Linux
```

Build output:
- macOS: `Export/macos/bin/`
- Windows: `Export/windows/bin/`
- Linux: `Export/linux/bin/`

### Step 5: Run

```bash
open Export/macos/bin/*.app          # macOS
# Export\windows\bin\FNF.exe         # Windows
# Export/linux/bin/FNF               # Linux
```

---

## Rendering Features

### Graphics API Switching

Psych Engine supports runtime switching between graphics APIs. The available APIs depend on your platform:

| Platform | Available APIs | Default |
|---|---|---|
| **macOS** | Metal, OpenGL | Metal |
| **Windows** | DirectX 12, DirectX 11, DirectX 9, Vulkan, OpenGL | DirectX 12 |
| **Linux** | Vulkan, OpenGL | Vulkan |

**Auto mode**: press ENTER on "Auto" to benchmark all available APIs (3 seconds each) and select the one with the best stability score (sustained FPS × frame time consistency).

```
Options → Graphics → Graphics API
```

### Resolution & Upscaling

The game window is fixed at 1280×720. The Resolution setting controls the **internal render resolution** — the game renders at this resolution, then the selected upscaler scales it to fill the window.

#### Resolution Options

```
Options → Graphics → Resolution
```

| Label | Internal Resolution |
|---|---|
| 240p | 426×240 |
| 360p | 640×360 |
| 480p | 854×480 |
| 720p | 1280×720 (window native) |
| 1080p | 1920×1080 |
| 1440p | 2560×1440 |
| 2160p | 3840×2160 |
| 2880p | 5120×2880 |
| 3240p | 5760×3240 |
| 4320p | 7680×4320 |
| 8640p | 15360×8640 |

Default on first launch: **1080p**.

#### Scale Up (active when resolution > 720p)

Press LEFT/RIGHT to preview, ENTER to confirm. If your GPU doesn't support the selected upscaler, a warning appears.

| Upscaler | GPU Required | Presets | Platform | Status |
|---|---|---|---|---|
| **Directly Enlarge** | None | — | All | Bilinear stretch |
| **NIS** | Any (shader) | — | All | NVIDIA Image Scaling — 4-directional Lanczos + adaptive sharpen |
| **FSR 1** | Any (shader) | — | All | AMD FidelityFX SR 1.0 — EASU + RCAS dual-pass |
| **MetalFX** | Apple Silicon / Intel Mac (macOS 13+) | Spatial, Temporal | macOS | Apple built-in upscaler |
| **DLSS** | NVIDIA RTX 20+ | Dynamic (driver-query) | Windows | NVIDIA Deep Learning Super Sampling |
| **XeSS** | Any with DP4a | 1.0, 1.1, 1.2, 1.3 | Windows | Intel Xe Super Sampling |

---

## Project Structure

```
FNF-PsychEngine-CustomAPI/
├── source/
│   ├── backend/
│   │   ├── GraphicsAPI.hx              # Multi-API selection & benchmarking
│   │   ├── GraphicsAPIType.hx          # API enum (Metal, Vulkan, D3D12, etc.)
│   │   ├── RenderDevice.hx             # bgfx rendering + upscaler pipeline
│   │   ├── BgfxAPI.hx                  # bgfx C bridge bindings (@:native)
│   │   ├── GPUDetect.hx                # GPU vendor/architecture detection
│   │   ├── ClientPrefs.hx              # Settings persistence
│   │   ├── BgfxFallback.hx             # bgfx init / OpenFL fallback
│   │   ├── BgfxWindowManager.hx        # Window resize handling
│   │   ├── BgfxTextureManager.hx       # GPU texture management
│   │   ├── BgfxShaderManager.hx        # Shader compilation & caching
│   │   └── upscale/
│   │       ├── IUpscaler.hx            # Upscaler interface
│   │       ├── DirectEnlargeUpscaler.hx
│   │       ├── NISUpscaler.hx
│   │       ├── FSRUpscaler.hx
│   │       ├── DLSSUpscaler.hx
│   │       ├── XeSSUpscaler.hx
│   │       └── MetalFXUpscaler.hx
│   ├── options/
│   │   ├── GraphicsSettingsSubState.hx # Resolution + Scale Up UI
│   │   └── UpscalerPresetSubState.hx   # Preset selector overlay (DLSS/XeSS/MetalFX)
│   ├── shaders/                        # bgfx GLSL shader sources
│   │   ├── fullscreenBlit.vert/frag    # Directly Enlarge blit shader
│   │   ├── nisUpscale.frag             # NIS upscale + sharpen
│   │   ├── fsrEASU.frag               # FSR 1 EASU pass
│   │   └── fsrRCAS.frag               # FSR 1 RCAS pass
│   └── states/PlayState.hx             # Toaster achievement (requires 240p)
├── libs/
│   ├── hxbgfx/
│   │   ├── project/
│   │   │   ├── Build.xml               # hxcpp linker config (all platforms)
│   │   │   ├── bgfx_bridge.h           # C bridge header
│   │   │   ├── bgfx_bridge.cpp         # C bridge implementation (bgfx wrappers)
│   │   │   └── build_bgfx_libs.sh      # bgfx library build script
│   │   ├── native/
│   │   │   ├── metalfx_bridge.mm       # MetalFX ObjC bridge
│   │   │   ├── dlss_bridge.h/cpp       # DLSS NGX bridge (Windows)
│   │   │   └── xess_bridge.h/cpp       # XeSS bridge (Windows)
│   │   └── lib/                        # Precompiled bgfx .a/.lib files
│   ├── dlss/                           # NVIDIA DLSS SDK headers + DLLs
│   └── xess/                           # Intel XeSS SDK headers + DLLs
├── assets/shaders/bgfx/                # Compiled shader .bin files
├── tools/
│   ├── shaderc                         # Prebuilt bgfx shader compiler (macOS ARM64)
│   ├── compile_shaders.sh              # Shader compilation script (macOS/Linux)
│   └── compile_shaders.bat             # Shader compilation script (Windows)
├── include/bgfx_bridge.h               # Lightweight C declarations for Haxe @:native
├── Project.xml                         # Lime/Haxe project config
└── setup/                              # Platform setup scripts
```

---

## Achievements

The "Toaster Gamer" achievement requires running the game at **240p resolution** with all graphics settings at minimum:

- `resolution = '240p'`
- `lowQuality = true`
- `shaders = false`
- `cacheOnGPU = false`
- `antialiasing = false`

Complete any song under these conditions to unlock it.

---

## Reference

- **Psych Engine:** [ShadowMario/FNF-PsychEngine](https://github.com/ShadowMario/FNF-PsychEngine)
- **bgfx:** [github.com/bkaradzic/bgfx](https://github.com/bkaradzic/bgfx)
- **DLSS SDK:** [NVIDIA Developer](https://developer.nvidia.com/rtx/dlss)
- **FSR 1:** [AMD GPUOpen](https://github.com/GPUOpen-Effects/FidelityFX-FSR) (MIT License)
- **XeSS SDK:** [Intel](https://github.com/intel/xess)
- **NIS:** [NVIDIA GameWorks](https://github.com/NVIDIAGameWorks/NVIDIAImageScaling) (MIT License)
- **MetalFX:** [Apple Documentation](https://developer.apple.com/documentation/metalfx)
- **Haxe:** [haxe.org](https://haxe.org) | **HaxeFlixel:** [haxeflixel.com](https://haxeflixel.com)
- **Friday Night Funkin':** [funkin.me](https://funkin.me)

---

## Credits

- **Shadow Mario** — Main Programmer, Head of Psych Engine
- **Riveren** — Main Artist/Animator
- **bbpanzu** — Ex-Team Member (Programmer)
- **crowplexus** — HScript Iris, Input System v3
- **Kamizeta** — Creator of Pessy (Psych Engine Mascot)
- **SqirraRNG** — Crash Handler, Chart Editor Waveform
- **EliteMasterEric** — Runtime Shaders Support
- **MAJigsaw77** — hxvlc Video Loader Library
- **iFlicky** — Composer of Psync, Tea Time
- **KadeDev** — Chart Editor Fixes
- **superpowers04** — LuaJIT Fork
- **CheemsAndFriends** — FlxAnimate
- **ninjamuffin99** — Friday Night Funkin' Creator

---

*Psych Engine by ShadowMario | Friday Night Funkin' by ninjamuffin99*
