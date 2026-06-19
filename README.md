![PsychEngineLogo](docs/img/Logo.png)

**Friday Night Funkin': Psych Engine** — A feature-rich FNF modding engine with multi-API rendering support (Metal, Vulkan, DirectX 12/11/9, OpenGL) and native FFmpeg video playback.

> 🇨🇳 [中文文档 (Chinese Documentation)](README_CN.md)

---

# Build Guide

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| **Haxe** | 4.3.6+ | [download](https://haxe.org/download/version/4.3.6) |
| **git** | any | [download](https://git-scm.com) |
| **macOS** | Xcode CLT 15+ / nasm | `xcode-select --install` + `brew install nasm` |
| **Windows** | Visual Studio 2022 | `VC.Tools.x86.x64` + `Windows10SDK.19041` |
| **Linux** | g++ 11+ / make / nasm | `sudo apt install g++ make nasm` |

## Quick Start

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

## Full Dependency List

Running `setup/unix.sh` or `setup/windows.bat` automatically installs all dependencies listed below.

### Haxelib Packages

| Package | Version | Install Command |
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

### Git Packages

| Package | Repository | Commit | Install Command |
|---|---|---|---|
| **flxanimate** | `https://github.com/Dot-Stuff/flxanimate` | `768740a` | `haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 768740a56b26aa0c072720e0d1236b94afe68e3e` |
| **linc_luajit** | `https://github.com/superpowers04/linc_luajit` | `1906c4a` | `haxelib git linc_luajit https://github.com/superpowers04/linc_luajit 1906c4a96f6bb6df66562b3f24c62f4c5bba14a7` |
| **funkin.vis** | `https://github.com/FunkinCrew/funkVis` | `22b1ce0` | `haxelib git funkin.vis https://github.com/FunkinCrew/funkVis 22b1ce089dd924f15cdc4632397ef3504d464e90` |
| **grig.audio** | `https://gitlab.com/haxe-grig/grig.audio.git` | `cbf91e2` | `haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git cbf91e2180fd2e374924fe74844086aab7891666` |

---

## FFmpeg Native Video Playback

Psych Engine uses a custom **FFmpeg native video decoder** (`source/ffmpeg/`) that replaces hxvlc entirely. No VLC or external players needed — FFmpeg is statically linked into the game binary. Players download and run — nothing else.

### Supported Formats

| Container | Video Codec | Audio Codec | Extension |
|---|---|---|---|
| **MP4** | H.264 (AVC) | AAC, MP3 | `.mp4` |
| **WebM** | VP9 | Vorbis, Opus | `.webm` |
| **MKV** | H.264 / VP9 | AAC, Vorbis, Opus | `.mkv` |

> Video is decoded to RGBA frames and rendered via BGFX textures. Decoding runs on a dedicated thread — zero main-thread blocking.

### Build FFmpeg Libraries

Before your first build, compile the FFmpeg static libraries:

```bash
# macOS / Linux
cd libs/ffmpeg/project
chmod +x build_ffmpeg_libs.sh
./build_ffmpeg_libs.sh

# Windows (requires Git Bash or WSL)
cd libs/ffmpeg/project
bash build_ffmpeg_libs.sh windows
```

Build output:
- `libs/ffmpeg/lib/macos/libavcodec.a` etc.
- `libs/ffmpeg/lib/windows/x64/avcodec.lib` etc.
- `libs/ffmpeg/lib/linux/x64/libavcodec.a` etc.
- `libs/ffmpeg/include/` — public headers

### Linux System FFmpeg

Linux users can also use the system package manager's FFmpeg. Build with `-D FFMPEG_SYSTEM`:

```bash
# Debian / Ubuntu
sudo apt install libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev

# Fedora
sudo dnf install ffmpeg-devel

# Arch
sudo pacman -S ffmpeg

# Then build with system FFmpeg
haxelib run lime build linux -D FFMPEG_SYSTEM
```

### Build Flags

In `Project.xml`:

```xml
<!-- Enable video playback (macOS, Windows, Linux; excludes 32-bit) -->
<define name="VIDEOS_ALLOWED" if="windows || linux || android || mac" unless="32bits"/>

<!-- FFmpeg build config (auto-included) -->
<include name="libs/ffmpeg/project/Build.xml" if="VIDEOS_ALLOWED" />

<!-- Use system FFmpeg instead of static linking (Linux only) -->
<!-- <define name="FFMPEG_SYSTEM" /> -->

<!-- Optional: enable FFmpeg debug logging (debug builds only) -->
<!-- Enabled by default in debug builds -->
<haxedef name="FFMPEG_DEBUG_LOGGING" if="VIDEOS_ALLOWED debug" />
```

### Lua API

```lua
-- Play video
startVideo("intro", true, false, false, true)
-- Arguments: (videoName, canSkip, forMidSong, shouldLoop, playOnLoad)

-- Video metadata queries
local t = getVideoTime()       -- Current playback position (seconds)
local d = getVideoDuration()   -- Total duration (seconds)
seekVideo(10.5)                -- Seek to 10.5 seconds
```

### Usage in Mods

**Chart events (recommended):**
Place a custom event named `playvideo` with the video filename (without extension) as Value 1.

**Video file locations:**
- `mods/<yourMod>/videos/<name>.mp4` (mod-specific)
- `mods/<yourMod>/videos/<name>.webm`
- `assets/videos/<name>.mp4` (shared / fallback)
- `assets/videos/<name>.webm`

### Architecture

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

Key features:
- **Dedicated decode thread** — decoding runs on an independent `std::thread`, zero main-thread blocking
- **Zero-copy frame delivery** — RGBA frames written directly into a reused `BitmapData`, no extra allocations
- **BGFX texture reuse** — a single `FlxGraphic` is reused for the entire video, only the GPU texture is updated each frame
- **Automatic resource cleanup** — `destroy()` automatically stops the decode thread and frees all FFmpeg resources
- **Cross-platform** — Windows (DirectX 12/11/9, Vulkan), macOS (Metal), Linux (Vulkan) all supported

### Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| "Video not found" in debug | Video file missing or format unsupported | Ensure video is in `mods/<mod>/videos/` or `assets/videos/`, format `.mp4` or `.webm` |
| Build error: `'libavformat/avformat.h' file not found` | FFmpeg libraries not built | Run `libs/ffmpeg/project/build_ffmpeg_libs.sh` to build FFmpeg |
| Link error: undefined reference to `avformat_open_input` | FFmpeg libraries not linked | Verify `.a`/`.lib` files exist under `libs/ffmpeg/lib/<platform>/` |
| Video stuttering / low FPS | Software decoding bottleneck | Enable hardware acceleration (build script already includes VideoToolbox/DXVA2/VAAPI flags) |
| Green screen / black screen | Pixel format conversion failure | Check that the video codec is H.264 or VP9 |
| Linux: builds but runtime symbol errors | System FFmpeg version mismatch | Use `./build_ffmpeg_libs.sh linux` to build static libraries |

---

## bgfx Multi-API Rendering

Psych Engine uses bgfx for cross-platform multi-API rendering with runtime switching.

### Build bgfx Libraries

```bash
# macOS / Linux
cd libs/hxbgfx/project
chmod +x build_bgfx_libs.sh
./build_bgfx_libs.sh

# Windows (requires Git Bash or WSL)
cd libs/hxbgfx/project
bash build_bgfx_libs.sh
```

### API Support by Platform

| Platform | Available APIs | Default |
|---|---|---|
| **macOS** | Metal, OpenGL | Metal |
| **Windows** | DirectX 12, DirectX 11, DirectX 9, Vulkan, OpenGL | DirectX 12 |
| **Linux** | Vulkan, OpenGL | Vulkan |

---

## Project Structure

```
FNF-PsychEngine-CustomAPI/
├── source/                       # Haxe source
│   ├── backend/                  # Rendering backend + utilities
│   │   ├── GraphicsAPI.hx           # API selection / switching
│   │   ├── GraphicsAPIType.hx       # Enum type definitions
│   │   ├── RenderDevice.hx          # bgfx rendering abstraction
│   │   ├── BgfxAPI.hx               # bgfx C API interface
│   │   ├── BgfxFallback.hx          # Initialization / fallback
│   │   ├── BgfxWindowManager.hx     # Window management
│   │   ├── BgfxTextureManager.hx    # Texture management
│   │   ├── BgfxShaderManager.hx     # Shader management
│   │   ├── PsychCamera.hx           # bgfx camera
│   │   ├── ClientPrefs.hx           # Settings persistence
│   │   └── Paths.hx                 # Asset paths (supports mp4 + webm)
│   ├── ffmpeg/                   # FFmpeg native video system
│   │   ├── VideoDecoder.h           # C++ decoder header
│   │   ├── VideoDecoder.cpp         # C++ decoder implementation (avcodec+swscale)
│   │   ├── FFmpegVideoDecoder.hx    # Haxe CFFI bridge
│   │   ├── VideoTexture.hx          # BGFX video texture management
│   │   └── VideoSprite.hx           # FlxSprite video display
│   ├── objects/                  # Game objects
│   │   └── VideoSprite.hx           # Video playback wrapper (skip UI + callbacks)
│   ├── states/                   # Game states
│   │   └── PlayState.hx             # startVideo() API
│   ├── psychlua/                 # Lua scripting
│   │   └── FunkinLua.hx             # Lua video interface
│   ├── shaders/                  # Embedded GLSL shaders
│   └── options/                  # Settings menus
├── libs/                         # Native libraries
│   ├── hxbgfx/                   # bgfx rendering library
│   │   ├── project/
│   │   │   ├── Build.xml            # hxcpp linker config
│   │   │   ├── bgfx_bridge.cpp      # Platform window handle bridge
│   │   │   └── build_bgfx_libs.sh   # bgfx build script
│   │   └── lib/                     # Build artifacts
│   ├── ffmpeg/                   # FFmpeg video decode library
│   │   ├── project/
│   │   │   ├── Build.xml            # hxcpp linker config
│   │   │   └── build_ffmpeg_libs.sh # FFmpeg build script
│   │   ├── include/                 # FFmpeg headers (after build)
│   │   └── lib/                     # Build artifacts
│   │       ├── macos/
│   │       ├── windows/x64/
│   │       └── linux/x64/
├── Project.xml                   # Lime project config
├── setup/                        # Platform setup scripts
│   ├── unix.sh
│   ├── windows.bat
│   └── windows-msvc.bat
├── assets/                       # Game assets
└── docs/                         # Documentation
```

---

## Customization

### Graphics API

In `Project.xml`:

```xml
<!-- bgfx multi-API rendering (enabled by default) -->
<define name="BGFX_RENDERER" />

<!-- Force a specific API at compile time (optional) -->
<!-- -D GRAPHICS_API_OPENGL    Force OpenGL -->
<!-- -D GRAPHICS_API_METAL     Force Metal -->
<!-- -D GRAPHICS_API_VULKAN    Force Vulkan -->
<!-- -D GRAPHICS_API_DIRECTX12 Force DirectX 12 -->
<!-- -D GRAPHICS_API_DIRECTX11 Force DirectX 11 -->
<!-- -D GRAPHICS_API_DIRECTX9  Force DirectX 9 -->
```

In the in-game settings menu (runtime switching, takes effect immediately):

```
Options → Graphics → Graphics Rendering API
  - Auto: benchmarks all available APIs on your GPU and picks the one with
    the best stability score (press ENTER to run)
  - Metal / DirectX 12 / DirectX 11 / DirectX 9 / Vulkan
  - OpenGL
```

### First-Run Setup

On the very first launch, before the title screen appears, Psych Engine asks:

> "Looks like it is your first time running the Custom API Psych Engine!
>  Do you want to do a test for the best graphics API for your computer?"

- **Yes** — runs the full GPU benchmark and saves the winning API.
- **No** — skips the benchmark and defaults to OpenGL.

This dialog only appears once (the result is persisted). To change APIs later, go to `Options → Graphics → Graphics Rendering API`.

### Auto API Detection

When "Auto" is selected and confirmed (ENTER) in the Graphics Settings menu, Psych Engine benchmarks every available graphics API over a 3-second time window — recording per-frame timestamps to measure both sustained FPS and frame time consistency (standard deviation). The API with the best **stability score** (sustained FPS × consistency) is saved and used for all subsequent sessions.

- The benchmark runs synchronously and typically completes in ~15 seconds on Windows with 5 APIs (3 seconds per API). On modern GPUs with fewer APIs, it is faster.
- To re-run the benchmark, select "Auto" and press ENTER again.
- Results are persisted to the save file and used directly on subsequent launches.

### Feature Toggles

Comment out or delete the corresponding lines in `Project.xml`:

| Feature | Define |
|---|---|
| Lua scripting | `LUA_ALLOWED` |
| HScript | `HSCRIPT_ALLOWED` |
| Video playback | `VIDEOS_ALLOWED` |
| FFmpeg system libs (Linux) | `FFMPEG_SYSTEM` |
| Discord RPC | `DISCORD_ALLOWED` |
| Mod support | `MODS_ALLOWED` |
| Achievements | `ACHIEVEMENTS_ALLOWED` |

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
