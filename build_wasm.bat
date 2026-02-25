@echo off

set sources=log app gfx glue time audio debugtext shape gl

call :build_backend gl SOKOL_GLES3
call :build_backend wgpu SOKOL_WGPU --use-port=emdawnwebgpu
goto :eof

:build_backend
set backend=%1
set define=%2
shift
shift
set extra_flags=%*

for %%s in (%sources%) do (
    echo %%s\sokol_%%s_wasm_%backend%_debug.a
    call emcc -c -g -DIMPL -D%define% %extra_flags% c\sokol_%%s.c
    call emar rcs %%s\sokol_%%s_wasm_%backend%_debug.a sokol_%%s.o
    del sokol_%%s.o
)

for %%s in (%sources%) do (
    echo %%s\sokol_%%s_wasm_%backend%_release.a
    call emcc -c -O2 -DNDEBUG -DIMPL -D%define% %extra_flags% c\sokol_%%s.c
    call emar rcs %%s\sokol_%%s_wasm_%backend%_release.a sokol_%%s.o
    del sokol_%%s.o
)
goto :eof
