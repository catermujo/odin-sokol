@echo off

setlocal EnableDelayedExpansion

set "SOURCES=log app gfx glue time audio debugtext shape gl"
set "EMCC_BIN=emcc"
set "EMAR_BIN=emar"

call :build_backend gl SOKOL_GLES3 || exit /b 1
call :build_backend wgpu SOKOL_WGPU --use-port=emdawnwebgpu || exit /b 1
exit /b 0

:build_backend
set "BACKEND=%~1"
set "DEFINE=%~2"
shift
shift
set "EXTRA_FLAGS=%*"

for %%s in (%SOURCES%) do (
    call :build_variant %%s %BACKEND% %DEFINE% debug %EXTRA_FLAGS% || exit /b 1
    call :build_variant %%s %BACKEND% %DEFINE% release %EXTRA_FLAGS% || exit /b 1
)
exit /b 0

:build_variant
set "PACKAGE=%~1"
set "BACKEND=%~2"
set "DEFINE=%~3"
set "CONFIG=%~4"
shift
shift
shift
shift
set "EXTRA_FLAGS=%*"
set "OUTPUT=%PACKAGE%\sokol_%PACKAGE%_wasm_%BACKEND%_%CONFIG%.a"

echo %OUTPUT%
if /I "%CONFIG%"=="release" (
    call %EMCC_BIN% -c -O2 -DNDEBUG -DIMPL -D%DEFINE% %EXTRA_FLAGS% c\sokol_%PACKAGE%.c || exit /b 1
) else (
    call %EMCC_BIN% -c -g -DIMPL -D%DEFINE% %EXTRA_FLAGS% c\sokol_%PACKAGE%.c || exit /b 1
)
call %EMAR_BIN% rcs %OUTPUT% sokol_%PACKAGE%.o || exit /b 1
if exist sokol_%PACKAGE%.o del sokol_%PACKAGE%.o
exit /b 0
