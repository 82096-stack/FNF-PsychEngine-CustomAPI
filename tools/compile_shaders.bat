@echo off
REM ============================================================================
REM compile_shaders.bat — Compile bgfx shaders for Windows
REM
REM Prerequisites:
REM   - bgfx shaderc.exe (download from https://github.com/bkaradzic/bgfx/releases)
REM     Place shaderc.exe in tools\ or add to PATH.
REM
REM Usage:
REM   compile_shaders.bat            Compile for D3D11 (default)
REM   compile_shaders.bat d3d12      Compile for D3D12
REM   compile_shaders.bat vulkan     Compile for Vulkan (SPIR-V)
REM   compile_shaders.bat all        Compile all Windows backends
REM
REM Output:
REM   assets\shaders\bgfx\  — platform-specific .bin files
REM ============================================================================

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set SHADER_SRC=%PROJECT_DIR%\source\shaders
set SHADER_OUT=%PROJECT_DIR%\assets\shaders\bgfx
set VARYING_DEF=%SHADER_SRC%\varying.def

REM ── Parse argument ────────────────────────────────────────────────────────
if "%~1"=="" (set PLATFORM=d3d11) else (set PLATFORM=%~1)

REM ── Find shaderc.exe ──────────────────────────────────────────────────────
set SHADERC=
where shaderc.exe >nul 2>&1 && set SHADERC=shaderc.exe
if not defined SHADERC if exist "%SCRIPT_DIR%shaderc.exe"    set SHADERC=%SCRIPT_DIR%shaderc.exe
if not defined SHADERC if exist "%SCRIPT_DIR%bgfx\shaderc.exe" set SHADERC=%SCRIPT_DIR%bgfx\shaderc.exe

if not defined SHADERC (
    echo ================================================================
    echo   shaderc.exe not found!
    echo.
    echo   Download from: https://github.com/bkaradzic/bgfx/releases
    echo   Place shaderc.exe in tools\ or add to PATH.
    echo ================================================================
    exit /b 1
)

echo Using: %SHADERC%
echo Target: %PLATFORM%

REM ── Create output dir ─────────────────────────────────────────────────────
if not exist "%SHADER_OUT%" mkdir "%SHADER_OUT%"

REM ── Generate varying.def ──────────────────────────────────────────────────
if not exist "%VARYING_DEF%" (
    (
        echo vec2 v_texcoord0 : TEXCOORD0 = vec2(0.0, 0.0^);
        echo.
        echo vec2 a_position  : POSITION;
        echo vec2 a_texcoord0 : TEXCOORD0;
    ) > "%VARYING_DEF%"
    echo Created varying.def
)

REM ── Compile one platform ──────────────────────────────────────────────────
:do_platform
REM %1 = platform tag (windows/linux), %2 = vs profile, %3 = ps profile
echo.
echo === %1 ===
for %%F in ("%SHADER_SRC%\*.vert") do (
    echo   %%~nxF
    "%SHADERC%" -f "%%F" -o "%SHADER_OUT%\%%~nxF.bin" --type vertex   --platform %1 -p %2 --varyingdef "%VARYING_DEF%" --verbose 2>&1 | findstr /v "^$"
    if !errorlevel! neq 0 echo   ERROR: %%~nxF
)
for %%F in ("%SHADER_SRC%\*.frag") do (
    echo   %%~nxF
    "%SHADERC%" -f "%%F" -o "%SHADER_OUT%\%%~nxF.bin" --type fragment --platform %1 -p %3 --varyingdef "%VARYING_DEF%" --verbose 2>&1 | findstr /v "^$"
    if !errorlevel! neq 0 echo   ERROR: %%~nxF
)
goto :eof

REM ── Dispatch ──────────────────────────────────────────────────────────────
if "%PLATFORM%"=="d3d11"  call :do_platform windows vs_5_0 ps_5_0
if "%PLATFORM%"=="d3d12"  call :do_platform windows vs_5_0 ps_5_0
if "%PLATFORM%"=="vulkan" call :do_platform linux   spirv spirv
if "%PLATFORM%"=="all" (
    call :do_platform windows vs_5_0 ps_5_0
    call :do_platform linux   spirv spirv
)

echo.
echo Done! Output: %SHADER_OUT%
endlocal
