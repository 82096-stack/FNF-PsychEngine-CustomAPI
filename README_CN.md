![PsychEngineLogo](docs/img/Logo.png)

**Friday Night Funkin': Psych Engine** — 功能丰富的 FNF 模组引擎，支持多 API 渲染（Metal, Vulkan, DirectX 12/11, OpenGL），八种画面放大方式（DLSS, FSR 1/2/3.1, XeSS, MetalFX, NIS, Directly Enlarge），以及 hxvlc (libVLC) GPU 加速视频播放。

> 🇺🇸 [English Documentation](README.md)

---

# 编译指南

> 📘 **详细编译说明请查看：**
> - [macOS 编译指南](docs/building/BUILDING_macos_zh.md)
> - [Windows 编译指南](docs/building/BUILDING_windows_zh.md)
> - [Linux 编译指南](docs/building/BUILDING_linux_zh.md)

## 快速开始

```bash
git clone <repo-url>
cd FNF-PsychEngine-CustomAPI

# 安装 Haxe 依赖
./setup/unix.sh          # macOS / Linux
# setup\windows.bat      # Windows

# 编译 bgfx（含 Vulkan 补丁）
cd libs/hxbgfx
./build_macos.sh          # macOS
# build_windows.bat       # Windows
# ./build_linux_x64.sh    # Linux

# 编译运行
cd ../..
haxelib run lime build mac     # macOS
haxelib run lime build windows # Windows
haxelib run lime build linux   # Linux
```

> ⚠️ bgfx 使用打过补丁的版本（暴露 Vulkan 句柄以支持 DLSS/XeSS），不能用 GitHub 原版替代。

## 渲染功能

### 多图形 API 切换

Psych Engine 支持运行时切换图形 API，可用 API 取决于平台：

| 平台 | 可选 API | 默认 |
|---|---|---|
| **macOS** | Metal, OpenGL | Metal |
| **Windows** | DirectX 12, DirectX 11, DirectX 9, Vulkan, OpenGL | DirectX 12 |
| **Linux** | Vulkan, OpenGL | Vulkan |

**Auto 模式**：在 "Auto" 上按 ENTER，将对所有可用 API 进行基准测试（每个 3 秒），选择稳定性得分最高（持续帧率 × 帧时间一致性）的 API。

```
Options → Graphics → Graphics API（选项 → 图像 → 图形 API）
```

### 分辨率与画面放大

游戏窗口固定为 1280×720。分辨率设置控制的是**内部渲染分辨率**——游戏以此分辨率渲染，然后通过选中的放大器缩放至填满窗口。

#### 分辨率选项

```
Options → Graphics → Resolution（选项 → 图像 → 分辨率）
```

| 标签 | 内部分辨率 |
|---|---|
| 240p | 426×240 |
| 360p | 640×360 |
| 480p | 854×480 |
| 720p | 1280×720（窗口原生分辨率） |
| 1080p | 1920×1080 |
| 1440p | 2560×1440 |
| 2160p | 3840×2160 |
| 2880p | 5120×2880 |
| 3240p | 5760×3240 |
| 4320p | 7680×4320 |
| 8640p | 15360×8640 |

首次启动默认值：**1080p**。

#### 画面放大（分辨率 > 720p 时激活）

按左/右预览，ENTER 确认。如果 GPU 不支持选中的放大器，会显示警告文字。

| 放大器 | GPU 需求 | 预设 | 平台 | 说明 |
|---|---|---|---|---|
| **Directly Enlarge** | 无 | — | 全平台 | 双线性拉伸 |
| **NIS** | 任意（纯着色器） | — | 全平台 | NVIDIA Image Scaling——4 方向 Lanczos + 自适应锐化 |
| **FSR 1** | 任意（纯着色器） | — | 全平台 | AMD FidelityFX SR 1.0——EASU + RCAS 双 Pass |
| **MetalFX** | Apple Silicon / Intel Mac (macOS 13+) | Spatial, Temporal | macOS | Apple 内置放大器 |
| **DLSS** | NVIDIA RTX 20+ | 动态（驱动查询） | Windows | NVIDIA 深度学习超采样 |
| **XeSS** | 任意 DP4a 显卡 | 1.0, 1.1, 1.2, 1.3 | Windows | Intel Xe 超采样 |

---

## 项目结构

```
FNF-PsychEngine-CustomAPI/
├── source/
│   ├── backend/
│   │   ├── GraphicsAPI.hx              # 多 API 选择与基准测试
│   │   ├── GraphicsAPIType.hx          # API 枚举（Metal, Vulkan, D3D12 等）
│   │   ├── RenderDevice.hx             # bgfx 渲染 + 放大器管线
│   │   ├── BgfxAPI.hx                  # bgfx C 桥接绑定 (@:native)
│   │   ├── GPUDetect.hx                # GPU 厂商/架构检测
│   │   ├── ClientPrefs.hx              # 设置持久化
│   │   ├── BgfxFallback.hx             # bgfx 初始化 / OpenFL 回退
│   │   ├── BgfxWindowManager.hx        # 窗口调整处理
│   │   ├── BgfxTextureManager.hx       # GPU 纹理管理
│   │   ├── BgfxShaderManager.hx        # 着色器编译与缓存
│   │   └── upscale/
│   │       ├── IUpscaler.hx            # 放大器接口
│   │       ├── DirectEnlargeUpscaler.hx
│   │       ├── NISUpscaler.hx
│   │       ├── FSRUpscaler.hx
│   │       ├── DLSSUpscaler.hx
│   │       ├── XeSSUpscaler.hx
│   │       └── MetalFXUpscaler.hx
│   ├── options/
│   │   ├── GraphicsSettingsSubState.hx # 分辨率 + 放大 UI
│   │   └── UpscalerPresetSubState.hx   # 预设选择器（DLSS/XeSS/MetalFX）
│   ├── shaders/                        # bgfx GLSL 着色器源码
│   │   ├── fullscreenBlit.vert/frag    # Directly Enlarge 着色器
│   │   ├── nisUpscale.frag             # NIS 放大 + 锐化
│   │   ├── fsrEASU.frag               # FSR 1 EASU Pass
│   │   └── fsrRCAS.frag               # FSR 1 RCAS Pass
│   └── states/PlayState.hx             # 烤面包机成就（需 240p 分辨率）
├── libs/
│   ├── hxbgfx/
│   │   ├── project/
│   │   │   ├── Build.xml               # hxcpp 链接配置（全平台）
│   │   │   ├── bgfx_bridge.h           # C 桥接头文件
│   │   │   ├── bgfx_bridge.cpp         # C 桥接实现（bgfx 包装）
│   │   │   └── build_bgfx_libs.sh      # bgfx 库编译脚本
│   │   ├── native/
│   │   │   ├── metalfx_bridge.mm       # MetalFX ObjC 桥接
│   │   │   ├── dlss_bridge.h/cpp       # DLSS NGX 桥接（Windows）
│   │   │   └── xess_bridge.h/cpp       # XeSS 桥接（Windows）
│   │   └── lib/                        # 预编译 bgfx .a/.lib 文件
│   ├── dlss/                           # NVIDIA DLSS SDK 头文件 + DLL
│   └── xess/                           # Intel XeSS SDK 头文件 + DLL
├── assets/shaders/bgfx/                # 编译后的着色器 .bin 文件
├── tools/
│   ├── shaderc                         # 预编译 bgfx 着色器编译器（macOS ARM64）
│   ├── compile_shaders.sh              # 着色器编译脚本（macOS/Linux）
│   └── compile_shaders.bat             # 着色器编译脚本（Windows）
├── include/bgfx_bridge.h               # 轻量 C 声明（供 Haxe @:native 使用）
├── Project.xml                         # Lime/Haxe 项目配置
└── setup/                              # 平台安装脚本
```

---

## 成就

"Toaster Gamer"（烤面包机玩家）成就需要以 **240p 分辨率**运行游戏，且所有画质设为最低：

- `resolution = '240p'`
- `lowQuality = true`
- `shaders = false`
- `cacheOnGPU = false`
- `antialiasing = false`

在此条件下完成任意一首歌即可解锁。

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
