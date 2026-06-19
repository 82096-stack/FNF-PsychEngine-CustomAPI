![PsychEngineLogo](docs/img/Logo.png)

**Friday Night Funkin': Psych Engine** — 功能丰富的 FNF 模组引擎，支持多 API 渲染（Metal, Vulkan, DirectX 12/11/9, OpenGL）和原生 FFmpeg 视频播放。

> 🇺🇸 [English Documentation](README.md)

---

# 编译指南

## 前置依赖

| 依赖 | 版本 | 说明 |
|---|---|---|
| **Haxe** | 4.3.6+ | [下载](https://haxe.org/download/version/4.3.6) |
| **git** | 任意 | [下载](https://git-scm.com) |
| **macOS** | Xcode CLT 15+ / nasm | `xcode-select --install` + `brew install nasm` |
| **Windows** | Visual Studio 2022 | `VC.Tools.x86.x64` + `Windows10SDK.19041` |
| **Linux** | g++ 11+ / make / nasm | `sudo apt install g++ make nasm` |

## 快速开始

### macOS / Linux

```bash
cd FNF-PsychEngine-CustomAPI
chmod +x setup/unix.sh
./setup/unix.sh
haxelib run lime build mac     # macOS
haxelib run lime build linux   # Linux
```

### Windows

```cmd
cd FNF-PsychEngine-CustomAPI
setup\windows.bat
haxelib run lime build windows
```

## 完整依赖清单

执行 `setup/unix.sh` 或 `setup/windows.bat` 会自动安装以下所有依赖：

### Haxelib 包

| 包 | 版本 | 安装指令 |
|---|---|---|
| **lime** | 8.2.0 | `haxelib install lime 8.2.0` |
| **openfl** | 9.3.3 | `haxelib install openfl 9.3.3` |
| **flixel** | 5.6.1 | `haxelib install flixel 5.6.1` |
| **flixel-addons** | 3.2.2 | `haxelib install flixel-addons 3.2.2` |
| **flixel-tools** | 1.5.1 | `haxelib install flixel-tools 1.5.1` |
| **hscript-iris** | 1.1.3 | `haxelib install hscript-iris 1.1.3` |
| **tjson** | 1.4.0 | `haxelib install tjson 1.4.0` |
| **hxdiscord_rpc** | 1.2.4 | `haxelib install hxdiscord_rpc 1.2.4` |
| **hxcpp** | 4.3.2 | `haxelib install hxcpp 4.3.2` |

### Git 包

| 包 | 仓库 | Commit | 安装指令 |
|---|---|---|---|
| **flxanimate** | `https://github.com/Dot-Stuff/flxanimate` | `768740a` | `haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 768740a56b26aa0c072720e0d1236b94afe68e3e` |
| **linc_luajit** | `https://github.com/superpowers04/linc_luajit` | `1906c4a` | `haxelib git linc_luajit https://github.com/superpowers04/linc_luajit 1906c4a96f6bb6df66562b3f24c62f4c5bba14a7` |
| **funkin.vis** | `https://github.com/FunkinCrew/funkVis` | `22b1ce0` | `haxelib git funkin.vis https://github.com/FunkinCrew/funkVis 22b1ce089dd924f15cdc4632397ef3504d464e90` |
| **grig.audio** | `https://gitlab.com/haxe-grig/grig.audio.git` | `cbf91e2` | `haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git cbf91e2180fd2e374924fe74844086aab7891666` |

---

## FFmpeg 原生视频播放

Psych Engine 使用自研的 **FFmpeg 原生视频解码器**（`source/ffmpeg/`）替代了 hxvlc，无需安装 VLC 或任何外部播放器。FFmpeg 库静态链接到游戏二进制文件中，玩家无需额外安装任何软件。

### 支持的格式

| 容器 | 视频编码 | 音频编码 | 文件扩展名 |
|---|---|---|---|
| **MP4** | H.264 (AVC) | AAC, MP3 | `.mp4` |
| **WebM** | VP9 | Vorbis, Opus | `.webm` |
| **MKV** | H.264 / VP9 | AAC, Vorbis, Opus | `.mkv` |

> 视频解码为 RGBA 帧后通过 BGFX 纹理渲染。解码在独立线程中运行，不会阻塞主线程。

### 编译 FFmpeg 库

首次编译前，需要先编译 FFmpeg 静态库：

```bash
# macOS / Linux
cd libs/ffmpeg/project
chmod +x build_ffmpeg_libs.sh
./build_ffmpeg_libs.sh

# Windows（需要 Git Bash 或 WSL）
cd libs/ffmpeg/project
bash build_ffmpeg_libs.sh windows
```

构建产物放置在：
- `libs/ffmpeg/lib/macos/libavcodec.a` 等
- `libs/ffmpeg/lib/windows/x64/avcodec.lib` 等
- `libs/ffmpeg/lib/linux/x64/libavcodec.a` 等
- `libs/ffmpeg/include/` — 公共头文件

### Linux 系统 FFmpeg

Linux 用户也可使用系统包管理器安装的 FFmpeg，在编译时添加 `-D FFMPEG_SYSTEM`：

```bash
# Debian / Ubuntu
sudo apt install libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev

# Fedora
sudo dnf install ffmpeg-devel

# Arch
sudo pacman -S ffmpeg

# 然后编译时指定系统 FFmpeg
haxelib run lime build linux -D FFMPEG_SYSTEM
```

### 编译标志

在 `Project.xml` 中：

```xml
<!-- 启用视频播放（macOS, Windows, Linux; 排除 32-bit） -->
<define name="VIDEOS_ALLOWED" if="windows || linux || android || mac" unless="32bits"/>

<!-- FFmpeg 构建配置（自动包含） -->
<include name="libs/ffmpeg/project/Build.xml" if="VIDEOS_ALLOWED" />

<!-- 使用系统 FFmpeg 而非静态链接版本 (仅 Linux) -->
<!-- <define name="FFMPEG_SYSTEM" /> -->

<!-- 可选：启用 FFmpeg 调试日志（仅 debug 构建） -->
<!-- 已在 debug 构建中默认开启 -->
<haxedef name="FFMPEG_DEBUG_LOGGING" if="VIDEOS_ALLOWED debug" />
```

### Lua 接口

```lua
-- 播放视频
startVideo("intro", true, false, false, true)
-- 参数: (videoName, canSkip, forMidSong, shouldLoop, playOnLoad)

-- 新增：视频元数据查询
local t = getVideoTime()       -- 当前播放位置（秒）
local d = getVideoDuration()   -- 总时长（秒）
seekVideo(10.5)                -- 跳转到 10.5 秒
```

### Mod 中使用

**Chart events（推荐）：**
添加一个名为 `playvideo` 的自定义事件，Value 1 填写视频文件名（不含扩展名）。

**视频文件位置：**
- `mods/<yourMod>/videos/<name>.mp4`（mod 专用）
- `mods/<yourMod>/videos/<name>.webm`
- `assets/videos/<name>.mp4`（共享/回退）
- `assets/videos/<name>.webm`

### 架构

```
┌──────────────────────────────────────────────────────┐
│  PlayState / Lua (startVideo("videos/intro.mp4"))    │
├──────────────────────────────────────────────────────┤
│  objects.VideoSprite (FlxSpriteGroup + skip UI)      │
│    └─ ffmpeg.VideoSprite (FlxSprite, BGFX display)   │
│         ├─ FFmpegVideoDecoder (CFFI → native C++)    │
│         │    ├─ Decode thread:  avcodec (YUV→RGBA)   │
│         │    └─ Frame queue:    mutex + condition var │
│         └─ VideoTexture (BGFX GPU texture lifecycle) │
├──────────────────────────────────────────────────────┤
│  FFmpeg (libavcodec / libavformat / libswscale)      │
├──────────────────────────────────────────────────────┤
│  BGFX (DirectX 12/11/9 / Metal / Vulkan / OpenGL)    │
│    BgfxTextureManager → GPU texture → FlxSprite      │
└──────────────────────────────────────────────────────┘
```

关键特性：
- **解码线程分离** — 解码在独立 `std::thread` 中运行，主线程零阻塞
- **零拷贝帧传输** — RGBA 帧直接写入复用 `BitmapData`，无额外分配
- **BGFX 纹理复用** — 同一 `FlxGraphic` 全程复用，仅每帧更新 GPU 纹理
- **自动资源回收** — `destroy()` 自动停止解码线程并释放所有 FFmpeg 资源
- **跨平台** — Windows (DirectX 12/11/9, Vulkan), macOS (Metal), Linux (Vulkan) 全支持

### 故障排除

| 症状 | 原因 | 解决方案 |
|---|---|---|
| "Video not found" in debug | 视频文件不存在或格式不支持 | 确认视频在 `mods/<mod>/videos/` 或 `assets/videos/`，格式为 `.mp4` 或 `.webm` |
| 编译错误: `'libavformat/avformat.h' file not found` | FFmpeg 库未编译 | 运行 `libs/ffmpeg/project/build_ffmpeg_libs.sh` 编译 FFmpeg |
| 链接错误: undefined reference to `avformat_open_input` | FFmpeg 库未链接 | 确认 `libs/ffmpeg/lib/<platform>/` 下有对应 `.a`/`.lib` 文件 |
| 视频播放卡顿 / 帧率低 | 软件解码性能不足 | 启用硬件加速（构建脚本已包含 VideoToolbox/DXVA2/VAAPI 标志） |
| 绿屏 / 黑屏 | 像素格式转换失败 | 检查视频编码是否为 H.264 或 VP9 |
| Linux: 编译成功但运行时找不到符号 | 系统 FFmpeg 版本不匹配 | 使用 `./build_ffmpeg_libs.sh linux` 编译静态库 |

---

## bgfx 多 API 渲染

Psych Engine 使用 bgfx 实现跨平台多 API 渲染，支持运行时切换。

### 编译 bgfx 库

```bash
# macOS / Linux
cd libs/hxbgfx/project
chmod +x build_bgfx_libs.sh
./build_bgfx_libs.sh

# Windows（需要 Git Bash 或 WSL）
cd libs/hxbgfx/project
bash build_bgfx_libs.sh
```

### 各平台支持的 API

| 平台 | 可选 API | 默认 |
|---|---|---|
| **macOS** | Metal, OpenGL | Metal |
| **Windows** | DirectX 12, DirectX 11, DirectX 9, Vulkan, OpenGL | DirectX 12 |
| **Linux** | Vulkan, OpenGL | Vulkan |

---

## 项目结构

```
FNF-PsychEngine-CustomAPI/
├── source/                       # Haxe 源码
│   ├── backend/                  # 渲染后端 + 工具类
│   │   ├── GraphicsAPI.hx           # API 选择/切换
│   │   ├── GraphicsAPIType.hx       # 枚举类型定义
│   │   ├── RenderDevice.hx          # bgfx 渲染抽象层
│   │   ├── BgfxAPI.hx               # bgfx C API 接口
│   │   ├── BgfxFallback.hx          # 初始化/回退
│   │   ├── BgfxWindowManager.hx     # 窗口管理
│   │   ├── BgfxTextureManager.hx    # 纹理管理
│   │   ├── BgfxShaderManager.hx     # Shader 管理
│   │   ├── PsychCamera.hx           # bgfx 相机
│   │   ├── ClientPrefs.hx           # 设置存储
│   │   └── Paths.hx                 # 资源路径（支持 mp4 + webm）
│   ├── ffmpeg/                   # FFmpeg 原生视频系统
│   │   ├── VideoDecoder.h           # C++ 解码器头文件
│   │   ├── VideoDecoder.cpp         # C++ 解码器实现（avcodec+swscale）
│   │   ├── FFmpegVideoDecoder.hx    # Haxe CFFI 桥接
│   │   ├── VideoTexture.hx          # BGFX 视频纹理管理
│   │   └── VideoSprite.hx           # FlxSprite 视频显示
│   ├── objects/                  # 游戏对象
│   │   └── VideoSprite.hx           # 视频播放封装（skip UI + 回调）
│   ├── states/                   # 游戏状态
│   │   └── PlayState.hx             # startVideo() API
│   ├── psychlua/                 # Lua 脚本
│   │   └── FunkinLua.hx             # Lua 视频接口
│   ├── shaders/                  # 内嵌 GLSL Shader
│   └── options/                  # 设置菜单
├── libs/                         # 原生库
│   ├── hxbgfx/                   # bgfx 渲染库
│   │   ├── project/
│   │   │   ├── Build.xml            # hxcpp 链接配置
│   │   │   ├── bgfx_bridge.cpp      # 平台窗口句柄桥接
│   │   │   └── build_bgfx_libs.sh   # bgfx 编译脚本
│   │   └── lib/                     # 编译产物
│   ├── ffmpeg/                   # FFmpeg 视频解码库
│   │   ├── project/
│   │   │   ├── Build.xml            # hxcpp 链接配置
│   │   │   └── build_ffmpeg_libs.sh # FFmpeg 编译脚本
│   │   ├── include/                 # FFmpeg 头文件（编译后）
│   │   └── lib/                     # 编译产物
│   │       ├── macos/
│   │       ├── windows/x64/
│   │       └── linux/x64/
├── Project.xml                   # Lime 项目配置
├── setup/                        # 平台安装脚本
│   ├── unix.sh
│   ├── windows.bat
│   └── windows-msvc.bat
├── assets/                       # 游戏资源
└── docs/                         # 文档
```

---

## 配置选项

### 图形 API

在 `Project.xml` 中：

```xml
<!-- bgfx 多 API 渲染（默认启用） -->
<define name="BGFX_RENDERER" />

<!-- 强制指定编译时 API（可选） -->
<!-- -D GRAPHICS_API_OPENGL    强制 OpenGL -->
<!-- -D GRAPHICS_API_METAL     强制 Metal -->
<!-- -D GRAPHICS_API_VULKAN    强制 Vulkan -->
<!-- -D GRAPHICS_API_DIRECTX12 强制 DirectX 12 -->
<!-- -D GRAPHICS_API_DIRECTX11 强制 DirectX 11 -->
<!-- -D GRAPHICS_API_DIRECTX9  强制 DirectX 9 -->
```

在游戏设置中（运行时切换，即时生效）：

```
Options → Graphics → Graphics Rendering API
  - Auto: 自动测试所有可用 API 的 GPU 帧率并选择最快的
    （按 ENTER 运行测试；初次启动时使用平台启发式算法）
  - Metal / DirectX 12 / DirectX 11 / DirectX 9 / Vulkan
  - OpenGL
```

### Auto API 检测

当在图像设置中选择 "Auto" 并按下 ENTER 确认时，Psych Engine 会对每个可用的图形 API 进行 3 秒时间窗口测试 —— 记录每帧时间戳以测量持续帧率和帧时间一致性（标准差）。**稳定性得分**（持续帧率 × 一致性系数）最高的 API 将被保存并用于后续所有会话。

- 初次启动（未运行过测试前）：使用快速平台启发式算法（macOS → Metal, Windows → DirectX 12, Linux → Vulkan）
- 测试同步运行，在 5 个 API 的 Windows 系统上约需 15 秒（每个 API 3 秒）。现代 GPU 如果可用 API 较少则更快
- 如需重新测试，再次选择 "Auto" 并按 ENTER 即可
- 结果会持久保存到设置文件中，下次启动直接使用

### 其他功能开关

在 `Project.xml` 中注释/删除对应行：

| 功能 | Define |
|---|---|
| Lua 脚本 | `LUA_ALLOWED` |
| HScript | `HSCRIPT_ALLOWED` |
| 视频播放 | `VIDEOS_ALLOWED` |
| FFmpeg 系统库 (Linux) | `FFMPEG_SYSTEM` |
| Discord RPC | `DISCORD_ALLOWED` |
| Mod 支持 | `MODS_ALLOWED` |
| 成就系统 | `ACHIEVEMENTS_ALLOWED` |

---

## Reference

- **Psych Engine GitHub:** [ShadowMario/FNF-PsychEngine](https://github.com/ShadowMario/FNF-PsychEngine)
- **Psych Engine Lua Wiki:** [shadowmario.github.io/psychengine.lua](https://shadowmario.github.io/psychengine.lua)
- **FFmpeg:** [ffmpeg.org](https://ffmpeg.org)
- **Haxe:** [haxe.org](https://haxe.org)
- **OpenFL:** [openfl.org](https://openfl.org)
- **Lime:** [github.com/openfl/lime](https://github.com/openfl/lime)
- **HaxeFlixel:** [haxeflixel.com](https://haxeflixel.com)
- **bgfx:** [github.com/bkaradzic/bgfx](https://github.com/bkaradzic/bgfx)
- **Friday Night Funkin':** [funkin.me](https://funkin.me)

---

## Credits

- **Shadow Mario** — Main Programmer, Head of Psych Engine
- **Riveren** — Main Artist/Animator
- **bbpanzu** — Ex-Team Member (Programmer)
- **crowplexus** — HScript Iris, Input System v3
- **Kamizeta** — Creator of Pessy (Psych Engine Mascot)
- **MaxNeton** — Loading Screen Easter Egg Artist/Animator
- **Keoiki** — Note Splash Animations and Latin Alphabet
- **SqirraRNG** — Crash Handler, Chart Editor Waveform
- **EliteMasterEric** — Runtime Shaders Support
- **MAJigsaw77** — Original .MP4 Video Loader Library (hxvlc)
- **iFlicky** — Composer of Psync, Tea Time
- **KadeDev** — Chart Editor Fixes
- **superpowers04** — LUA JIT Fork
- **CheemsAndFriends** — FlxAnimate
- **Ezhalt** — Pessy Easter Egg Jingle
- **MaliciousBunny** — Final Update Video
- **ninjamuffin99** — Friday Night Funkin' Creator

---

*Psych Engine by ShadowMario | Friday Night Funkin' by ninjamuffin99*
