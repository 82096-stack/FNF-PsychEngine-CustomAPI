#!/bin/sh
# SETUP FOR MAC AND LINUX SYSTEMS!!!
# REMINDER THAT YOU NEED HAXE INSTALLED PRIOR TO USING THIS
# https://haxe.org/download
cd ..
echo Making the main haxelib and setuping folder in same time..
mkdir ~/haxelib && haxelib setup ~/haxelib
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.
haxelib install flixel 5.6.1
haxelib install flixel-addons 3.2.2
haxelib install flixel-tools 1.5.1
haxelib install hscript-iris 1.1.3
haxelib install tjson 1.4.0
haxelib install hxdiscord_rpc 1.2.4
haxelib install hxvlc 2.0.1 --skip-dependencies
haxelib install lime 8.2.0
haxelib install openfl 9.3.3
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 768740a56b26aa0c072720e0d1236b94afe68e3e
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit 1906c4a96f6bb6df66562b3f24c62f4c5bba14a7
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis 22b1ce089dd924f15cdc4632397ef3504d464e90
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git cbf91e2180fd2e374924fe74844086aab7891666

# bgfx multi-API rendering backend
haxelib dev hxbgfx libs/hxbgfx
echo "  hxbgfx registered — run 'libs/hxbgfx/project/build_bgfx_libs.sh' to compile bgfx libraries"

echo .
echo -----------------------------------------------
echo "hxvlc Video Playback — Installing VLC (libvlc) runtime dependency"
echo -----------------------------------------------
if [ "$(uname)" = "Darwin" ]; then
	if [ -d "/Applications/VLC.app" ]; then
		echo "  VLC already installed at /Applications/VLC.app"
	elif command -v brew &> /dev/null; then
		echo "  Installing VLC via Homebrew..."
		brew install --cask vlc
		echo "  VLC installed successfully"
	else
		echo "  Homebrew not found. Please install VLC manually:"
		echo "    https://www.videolan.org/vlc/"
		echo "  Or install Homebrew first:"
		echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
	fi
elif [ "$(uname)" = "Linux" ]; then
	if command -v apt &> /dev/null; then
		echo "  Installing libvlc-dev via apt..."
		sudo apt install -y libvlc-dev
	elif command -v dnf &> /dev/null; then
		echo "  Installing libvlc-devel via dnf..."
		sudo dnf install -y libvlc-devel
	elif command -v pacman &> /dev/null; then
		echo "  Installing vlc via pacman..."
		sudo pacman -S --noconfirm vlc
	else
		echo "  Could not detect package manager. Please install VLC / libvlc-dev manually."
	fi
fi
echo "  hxvlc version: 2.0.1"
echo "  VLC/libvlc is required at runtime for video playback (startVideo)."
echo Finished!
echo .
echo -----------------------------------------------
echo "Graphics Rendering — bgfx multi-backend (default):"
echo "  Build:  haxelib run lime build <target>"
echo "."
echo "  Runtime-switchable backends in settings:"
echo "    macOS:   Metal, OpenGL"
echo "    Windows: DirectX 12, Vulkan, OpenGL"
echo "    Linux:   Vulkan, OpenGL"
echo "."
echo "  First build: compile bgfx libs first"
echo "    cd libs/hxbgfx/project && ./build_bgfx_libs.sh"
echo -----------------------------------------------