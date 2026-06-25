@echo off
REM ================================================================
REM build_windows.bat — Build Windows bgfx (with Vulkan patches)
REM
REM Usage: build_windows.bat
REM Output: libs/hxbgfx/lib/windows/x64/bgfx.lib, bx.lib, bimg.lib
REM          libs/hxbgfx/lib/windows/x86/bgfx.lib, bx.lib, bimg.lib
REM
REM Prerequisites:
REM   - Git for Windows (https://git-scm.com/download/win)
REM   - Visual Studio 2022 (with C++ Desktop Development)
REM ================================================================
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set BUILD_DIR=%SCRIPT_DIR%.build
set GENIE=%BUILD_DIR%\bx\tools\bin\windows\genie.exe

echo === Building Windows bgfx (with Vulkan patches) ===

REM Check Git
where git >nul 2>nul || (echo ERROR: Git not found. Install from https://git-scm.com/download/win && pause && exit /b 1)

REM Clone sources
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
cd /d "%BUILD_DIR%"

if not exist "bgfx" (
    echo Cloning bgfx...
    git clone --depth 1 https://github.com/bkaradzic/bgfx.git bgfx
)
if not exist "bx" (
    echo Cloning bx...
    git clone --depth 1 https://github.com/bkaradzic/bx.git bx
)
if not exist "bimg" (
    echo Cloning bimg...
    git clone --depth 1 https://github.com/bkaradzic/bimg.git bimg
)

echo Sources ready

REM ==== Apply patches ====
echo Applying Vulkan patches...

set BGFX_H=%BUILD_DIR%\bgfx\include\bgfx\bgfx.h
set BGFX_C99=%BUILD_DIR%\bgfx\include\bgfx\c99\bgfx.h
set RENDERER_VK=%BUILD_DIR%\bgfx\src\renderer_vk.cpp

powershell -Command "(Get-Content '%BGFX_H%') -replace '(void\* context;.*//!< GL context, or D3D device.)', '`$1' + \"`r`n            void* vkInstance;           //!< VkInstance (Vulkan only, NULL otherwise)`r`n            void* vkPhysicalDevice;     //!< VkPhysicalDevice (Vulkan only)\" | Set-Content '%BGFX_H%'" 2>nul

powershell -Command "(Get-Content '%BGFX_C99%') -replace '(void\*                context;.*/\*\* GL context, or D3D device)', '`$1' + \"`r`n    void*                vkInstance;         /** VkInstance (Vulkan only) */`r`n    void*                vkPhysicalDevice;   /** VkPhysicalDevice (Vulkan only) */\" | Set-Content '%BGFX_C99%'" 2>nul

powershell -Command "(Get-Content '%RENDERER_VK%') -replace 'uintptr_t getInternal\(TextureHandle /\*_handle\*/\) override', 'uintptr_t getInternal(TextureHandle _handle) override' -replace 'return 0;', 'return (uintptr_t)(void*)m_textures[_handle.idx].m_textureImage;' | Set-Content '%RENDERER_VK%'" 2>nul

REM Patch 4: renderer_vk.cpp InternalData init (expose VK handles after device creation)
powershell -Command "$vk = Get-Content '%RENDERER_VK%' -Raw; $vk = $vk -replace '(errorState = ErrorState::DeviceCreated;)', '`$1' + \"`r`n`r`n                {   // PATCH: Expose Vulkan handles for DLSS/XeSS`r`n                    bgfx::InternalData* d = const_cast<bgfx::InternalData*>(bgfx::getInternalData());`r`n                    if (d) { d->vkInstance = (void*)m_instance; d->vkPhysicalDevice = (void*)m_physicalDevice; }`r`n                }\"; Set-Content '%RENDERER_VK%' $vk" 2>nul

REM Patch 5: glcontext_egl.cpp 64-bit pointer cast fix
if exist "%BUILD_DIR%\bgfx\src\glcontext_egl.cpp" (
    powershell -Command "$egl = Get-Content '%BUILD_DIR%\bgfx\src\glcontext_egl.cpp' -Raw; $egl = $egl -replace '\(EGLNativeWindowType\) m_eglWindow', '(EGLNativeWindowType)(uintptr_t) m_eglWindow' -replace '\(EGLNativeWindowType\)_nwh', '(EGLNativeWindowType)(uintptr_t)_nwh'; Set-Content '%BUILD_DIR%\bgfx\src\glcontext_egl.cpp' $egl" 2>nul
)

echo Patches applied (5/5)

REM Generate VS project
cd /d "%BUILD_DIR%\bgfx"
echo Generating Visual Studio project...
"%GENIE%" vs2022

REM Build x64
echo Building bgfx x64 Release...
msbuild .build\projects\vs2022\bgfx.sln /p:Configuration=Release /p:Platform=x64 /m 2>nul
msbuild .build\projects\vs2022\bx.sln /p:Configuration=Release /p:Platform=x64 /m 2>nul
msbuild .build\projects\vs2022\bimg.sln /p:Configuration=Release /p:Platform=x64 /m 2>nul

set LIB_OUT64=%SCRIPT_DIR%lib\windows\x64
if not exist "%LIB_OUT64%" mkdir "%LIB_OUT64%"
copy /Y "%BUILD_DIR%\bgfx\.build\win64_vs2022\bin\bgfxRelease.lib" "%LIB_OUT64%\bgfx.lib" 2>nul
copy /Y "%BUILD_DIR%\bx\.build\win64_vs2022\bin\bxRelease.lib"       "%LIB_OUT64%\bx.lib" 2>nul
copy /Y "%BUILD_DIR%\bimg\.build\win64_vs2022\bin\bimgRelease.lib"   "%LIB_OUT64%\bimg.lib" 2>nul
echo x64 build complete

REM Build x86
echo Building bgfx x86 Release...
msbuild .build\projects\vs2022\bgfx.sln /p:Configuration=Release /p:Platform=Win32 /m 2>nul
msbuild .build\projects\vs2022\bx.sln /p:Configuration=Release /p:Platform=Win32 /m 2>nul
msbuild .build\projects\vs2022\bimg.sln /p:Configuration=Release /p:Platform=Win32 /m 2>nul

set LIB_OUT86=%SCRIPT_DIR%lib\windows\x86
if not exist "%LIB_OUT86%" mkdir "%LIB_OUT86%"
copy /Y "%BUILD_DIR%\bgfx\.build\win32_vs2022\bin\bgfxRelease.lib" "%LIB_OUT86%\bgfx.lib" 2>nul
copy /Y "%BUILD_DIR%\bx\.build\win32_vs2022\bin\bxRelease.lib"       "%LIB_OUT86%\bx.lib" 2>nul
copy /Y "%BUILD_DIR%\bimg\.build\win32_vs2022\bin\bimgRelease.lib"   "%LIB_OUT86%\bimg.lib" 2>nul
echo x86 build complete

echo ================================================================
echo Windows bgfx build complete!
echo x64: %LIB_OUT64%
echo x86: %LIB_OUT86%
echo ================================================================
pause
