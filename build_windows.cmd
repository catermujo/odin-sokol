@echo off

setlocal EnableDelayedExpansion

set "SOKOL_WINDOWS_HOST_ARCH=%PROCESSOR_ARCHITECTURE%"
if not defined SOKOL_WINDOWS_HOST_ARCH set "SOKOL_WINDOWS_HOST_ARCH=x64"
if /I "%SOKOL_WINDOWS_HOST_ARCH%"=="AMD64" set "SOKOL_WINDOWS_HOST_ARCH=x64"
if /I "%SOKOL_WINDOWS_HOST_ARCH%"=="ARM64" set "SOKOL_WINDOWS_HOST_ARCH=arm64"

set "SOKOL_WINDOWS_ARCH=%~1"
if "%SOKOL_WINDOWS_ARCH%"=="" set "SOKOL_WINDOWS_ARCH=%SOKOL_WINDOWS_HOST_ARCH%"
if /I "%SOKOL_WINDOWS_ARCH%"=="x64" set "SOKOL_WINDOWS_ARCH=x64"
if /I "%SOKOL_WINDOWS_ARCH%"=="amd64" set "SOKOL_WINDOWS_ARCH=x64"
if /I "%SOKOL_WINDOWS_ARCH%"=="arm64" set "SOKOL_WINDOWS_ARCH=arm64"
if not "%SOKOL_WINDOWS_ARCH%"=="x64" if not "%SOKOL_WINDOWS_ARCH%"=="arm64" (
    echo ERROR: Unsupported target architecture '%SOKOL_WINDOWS_ARCH%'. Expected x64 or arm64.
    exit /b 1
)

call :ensure_msvc || exit /b 1

set sources=log app gfx glue time audio debugtext shape gl

REM D3D11 Debug
for %%s in (%sources%) do (
    cl /c /D_DEBUG /DIMPL /DSOKOL_D3D11 c\sokol_%%s.c /Z7 || exit /b 1
    lib /OUT:%%s\sokol_%%s_windows_%SOKOL_WINDOWS_ARCH%_d3d11_debug.lib sokol_%%s.obj || exit /b 1
    if exist sokol_%%s.obj del sokol_%%s.obj
)

REM D3D11 Release
for %%s in (%sources%) do (
    cl /c /O2 /DNDEBUG /DIMPL /DSOKOL_D3D11 c\sokol_%%s.c || exit /b 1
    lib /OUT:%%s\sokol_%%s_windows_%SOKOL_WINDOWS_ARCH%_d3d11_release.lib sokol_%%s.obj || exit /b 1
    if exist sokol_%%s.obj del sokol_%%s.obj
)

REM GL Debug
for %%s in (%sources%) do (
    cl /c /D_DEBUG /DIMPL /DSOKOL_GLCORE c\sokol_%%s.c /Z7 || exit /b 1
    lib /OUT:%%s\sokol_%%s_windows_%SOKOL_WINDOWS_ARCH%_gl_debug.lib sokol_%%s.obj || exit /b 1
    if exist sokol_%%s.obj del sokol_%%s.obj
)

REM GL Release
for %%s in (%sources%) do (
    cl /c /O2 /DNDEBUG /DIMPL /DSOKOL_GLCORE c\sokol_%%s.c || exit /b 1
    lib /OUT:%%s\sokol_%%s_windows_%SOKOL_WINDOWS_ARCH%_gl_release.lib sokol_%%s.obj || exit /b 1
    if exist sokol_%%s.obj del sokol_%%s.obj
)

REM D3D11 Debug DLL
cl /D_DEBUG /DIMPL /DSOKOL_DLL /DSOKOL_D3D11 c\sokol.c /Z7 /LDd /MDd /DLL /Fe:sokol_dll_windows_%SOKOL_WINDOWS_ARCH%_d3d11_debug.dll /link /INCREMENTAL:NO || exit /b 1

REM D3D11 Release DLL
REM DUMBAI: Keep the release DLLs aligned with the release static libraries by compiling them without debug defines.
cl /DNDEBUG /DIMPL /DSOKOL_DLL /DSOKOL_D3D11 c\sokol.c /LD /MD /DLL /Fe:sokol_dll_windows_%SOKOL_WINDOWS_ARCH%_d3d11_release.dll /link /INCREMENTAL:NO || exit /b 1

REM GL Debug DLL
cl /D_DEBUG /DIMPL /DSOKOL_DLL /DSOKOL_GLCORE c\sokol.c /Z7 /LDd /MDd /DLL /Fe:sokol_dll_windows_%SOKOL_WINDOWS_ARCH%_gl_debug.dll /link /INCREMENTAL:NO || exit /b 1

REM GL Release DLL
cl /DNDEBUG /DIMPL /DSOKOL_DLL /DSOKOL_GLCORE c\sokol.c /LD /MD /DLL /Fe:sokol_dll_windows_%SOKOL_WINDOWS_ARCH%_gl_release.dll /link /INCREMENTAL:NO || exit /b 1

if exist sokol.obj del sokol.obj

exit /b 0

:ensure_msvc
where cl >nul 2>nul
if not errorlevel 1 goto :eof

REM DUMBAI: Bootstrap the MSVC environment so this script also works from a plain terminal.
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
    echo ERROR: Could not find vswhere.exe.
    exit /b 1
)
for /f "usebackq delims=" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%I"
if not defined VSINSTALL (
    echo ERROR: Could not find a Visual Studio installation with MSVC tools.
    exit /b 1
)
call "%VSINSTALL%\VC\Auxiliary\Build\vcvarsall.bat" %SOKOL_WINDOWS_HOST_ARCH% %SOKOL_WINDOWS_ARCH% >nul || exit /b 1
goto :eof
