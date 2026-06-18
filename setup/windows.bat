@echo off
color 0a
cd ..
@echo on
echo ======================================================
echo Psych Engine - Windows Dependency Setup
echo ======================================================
echo.
echo [1/3] Installing haxelib packages (pinned versions)...
echo.

echo   lime 8.2.0
haxelib install lime 8.2.0

echo   openfl 9.3.3
haxelib install openfl 9.3.3

echo   flixel 5.6.1
haxelib install flixel 5.6.1

echo   flixel-addons 3.2.2
haxelib install flixel-addons 3.2.2

echo   flixel-tools 1.5.1
haxelib install flixel-tools 1.5.1

echo   hscript-iris 1.1.3
haxelib install hscript-iris 1.1.3

echo   tjson 1.4.0
haxelib install tjson 1.4.0

echo   hxdiscord_rpc 1.2.4
haxelib install hxdiscord_rpc 1.2.4

echo   hxcpp 4.3.2
haxelib install hxcpp 4.3.2

echo.
echo [2/3] Installing git packages (pinned commits)...
echo.

echo   flxanimate (Dot-Stuff/flxanimate @ 768740a)
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 768740a56b26aa0c072720e0d1236b94afe68e3e

echo   linc_luajit (superpowers04/linc_luajit @ 1906c4a)
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit 1906c4a96f6bb6df66562b3f24c62f4c5bba14a7

echo   funkin.vis (FunkinCrew/funkVis @ 22b1ce0)
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis 22b1ce089dd924f15cdc4632397ef3504d464e90

echo   grig.audio (haxe-grig/grig.audio @ cbf91e2)
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git cbf91e2180fd2e374924fe74844086aab7891666

echo.
echo [3/3] Registering local dev libraries...
echo.

echo   hxbgfx (local dev lib)
haxelib dev hxbgfx libs/hxbgfx

echo.
echo ======================================================
echo Setup complete - all packages installed
echo ======================================================
echo.
echo ======================================================
echo   NEXT: Build native libraries before first compile
echo ======================================================
echo.
echo   [Required] FFmpeg - native video decoder:
echo     cd libs/ffmpeg/project
echo     bash build_ffmpeg_libs.sh windows
echo     (Requires Git Bash or WSL)
echo.
echo   [Required] bgfx - multi-API rendering backend:
echo     cd libs/hxbgfx/project
echo     bash build_bgfx_libs.sh
echo     (Requires Git Bash or WSL)
echo.
echo ------------------------------------------------------
echo   Build command:
echo     haxelib run lime build windows
echo ------------------------------------------------------
echo.
echo   Graphics backends (runtime-switchable):
echo     Windows: DirectX 12, Vulkan, OpenGL
echo.
echo   Video formats (native FFmpeg, no VLC required):
echo     MP4 (H.264), WebM (VP9), MKV
echo ======================================================
pause
