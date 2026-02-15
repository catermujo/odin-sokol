#!/bin/bash
set -e

WASM_THREAD_FLAGS=${WASM_THREAD_FLAGS:-"-pthread -matomics -mbulk-memory"}

declare -a libs=("log" "gfx" "app" "glue" "time" "audio" "debugtext" "shape" "gl")

build_backend() {
    local backend="$1"
    local define="$2"
    shift 2
    local extra_flags=("$@")

    for l in "${libs[@]}"; do
        echo "${l}/sokol_${l}_wasm_${backend}_debug.a"
        emcc -c -g -DIMPL -D"${define}" "${extra_flags[@]}" c/sokol_"$l".c
        emar rcs "$l"/sokol_"$l"_wasm_"$backend"_debug.a sokol_"$l".o
        rm sokol_"$l".o
    done

    for l in "${libs[@]}"; do
        echo "${l}/sokol_${l}_wasm_${backend}_release.a"
        emcc -c -O2 -DNDEBUG -DIMPL -D"${define}" "${extra_flags[@]}" c/sokol_"$l".c
        emar rcs "$l"/sokol_"$l"_wasm_"$backend"_release.a sokol_"$l".o
        rm sokol_"$l".o
    done
}

build_backend gl SOKOL_GLES3
build_backend wgpu SOKOL_WGPU --use-port=emdawnwebgpu

for l in "${libs[@]}"; do
    echo "${l}/sokol_${l}_wasm_gl_debug.a"
    emcc $WASM_THREAD_FLAGS -c -g -DIMPL -DSOKOL_GLES3 c/sokol_$l.c
    emar rcs $l/sokol_${l}_wasm_gl_debug.a sokol_$l.o
    rm sokol_$l.o
done

for l in "${libs[@]}"; do
    echo "${l}/sokol_${l}_wasm_gl_release.a"
    emcc $WASM_THREAD_FLAGS -c -O2 -DNDEBUG -DIMPL -DSOKOL_GLES3 c/sokol_$l.c
    emar rcs $l/sokol_${l}_wasm_gl_release.a sokol_$l.o
    rm sokol_$l.o
done
