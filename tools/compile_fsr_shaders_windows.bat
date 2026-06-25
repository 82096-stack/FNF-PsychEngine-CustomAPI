@echo off
REM ================================================================
REM compile_fsr_shaders_windows.bat — Compile FSR 2/3.1 Shaders (Windows)
REM
REM Usage: compile_fsr_shaders_windows.bat [dx11|dx12|all]
REM Default: dx11
REM Output: libs/fsr2/shaders_bgfx/dx11/*.bin  or  dx12/*.bin
REM
REM Prerequisites: shaderc.exe (from bgfx build or download)
REM ================================================================
setlocal enabledelayedexpansion

set SCRIPT_DIR=%/~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set SHADER_SRC=%PROJECT_DIR%\libs\fsr2\src\shaders
set SHADER_OUT=%PROJECT_DIR%\libs\fsr2\shaders_bgfx
set VARYING_DEF=%PROJECT_DIR%\source\shaders\varying.def
set SHADERC=%SCRIPT_DIR%shaderc.exe

set PLATFORM=%1
if "%PLATFORM%"=="" set PLATFORM=dx11

echo === FSR 2/3.1 Shader Compilation (Windows) ===

REM Check shaderc
if exist "%SHADERC%" (
    echo shaderc ready: %SHADERC%
    goto :compile
)

REM Try getting from bgfx build directory
if exist "%PROJECT_DIR%\libs\hxbgfx\.build\bgfx\.build\win64_vs2022\bin\shadercRelease.exe" (
    copy "%PROJECT_DIR%\libs\hxbgfx\.build\bgfx\.build\win64_vs2022\bin\shadercRelease.exe" "%SHADERC%"
    echo Copied from bgfx build directory shaderc
    goto :compile
)

echo ERROR: shaderc not found. Run build_windows.bat first to build bgfx.
echo   or download shaderc.exe from https://github.com/bkaradzic/bgfx/releases and place in tools\
pause
exit /b 1

:compile
if not exist "%SHADER_SRC%" (
    echo ERROR: Shader source directory not found: %SHADER_SRC%
    pause
    exit /b 1
)

REM Compilation function
set OK_COUNT=0
set FAIL_COUNT=0

echo Compiling %PLATFORM% shaders...

for %%f in ("%SHADER_SRC%\*.hlsl") do (
    set NAME=%%/~nf
    set PROFILE=%PLATFORM%

    if "%PLATFORM%"=="all" (
        REM dx11
        if not exist "%SHADER_OUT%\dx11" mkdir "%SHADER_OUT%\dx11"
        echo   !NAME!.hlsl ^→ dx11/!NAME!.bin
        "%SHADERC%" -f "%%f" -o "%SHADER_OUT%\dx11\!NAME!.bin" --platform windows --type compute --varyingdef "%VARYING_DEF%" -i "%SHADER_SRC%" -i "%PROJECT_DIR%\libs\fsr2\include" -i "%PROJECT_DIR%\libs\fsr2\include\internal" --define "FFX_FSR2=1" --define "FFX_GPU=1" 2>nul && set /a OK_COUNT+=1 || (echo    WARNING: !NAME! dx11 compilation failed && set /a FAIL_COUNT+=1)

        REM dx12
        if not exist "%SHADER_OUT%\dx12" mkdir "%SHADER_OUT%\dx12"
        echo   !NAME!.hlsl ^→ dx12/!NAME!.bin
        "%SHADERC%" -f "%%f" -o "%SHADER_OUT%\dx12\!NAME!.bin" --platform windows --type compute --profile dx12 --varyingdef "%VARYING_DEF%" -i "%SHADER_SRC%" -i "%PROJECT_DIR%\libs\fsr2\include" -i "%PROJECT_DIR%\libs\fsr2\include\internal" --define "FFX_FSR2=1" --define "FFX_GPU=1" 2>nul && set /a OK_COUNT+=1 || (echo    WARNING: !NAME! dx12 compilation failed && set /a FAIL_COUNT+=1)
    ) else (
        if not exist "%SHADER_OUT%\%PLATFORM%" mkdir "%SHADER_OUT%\%PLATFORM%"
        echo   !NAME!.hlsl ^→ %PLATFORM%/!NAME!.bin
        "%SHADERC%" -f "%%f" -o "%SHADER_OUT%\%PLATFORM%\!NAME!.bin" --platform windows --type compute --varyingdef "%VARYING_DEF%" -i "%SHADER_SRC%" -i "%PROJECT_DIR%\libs\fsr2\include" -i "%PROJECT_DIR%\libs\fsr2\include\internal" --define "FFX_FSR2=1" --define "FFX_GPU=1" 2>nul && set /a OK_COUNT+=1 || (echo    WARNING: !NAME! %PLATFORM% compilation failed && set /a FAIL_COUNT+=1)
    )
)

echo ================================================================
echo FSR 2/3.1 Shader compilation complete!
echo OK:  %OK_COUNT%  FAIL:  %FAIL_COUNT%
if not "%PLATFORM%"=="all" dir "%SHADER_OUT%\%PLATFORM%" 2>nul
echo ================================================================
echo Note: FFX framework shaders may need manual header dependency fixing.
echo If compilation failed, check #include paths in HLSL source.
pause
