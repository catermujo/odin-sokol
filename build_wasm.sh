#!/usr/bin/env bash

set -euo pipefail

EMCC_BIN=${EMCC:-emcc}
EMAR_BIN=${EMAR:-emar}
PACKAGES=(log app gfx glue time audio debugtext shape gl)

build_variant() {
    local package="$1"
    local backend="$2"
    local define="$3"
    local config="$4"
    shift 4
    local extra_flags=("$@")
    local output="${package}/sokol_${package}_wasm_${backend}_${config}.a"

    echo "$output"
    if [ "$config" = "release" ]; then
        "$EMCC_BIN" -c -O2 -DNDEBUG -DIMPL -D"${define}" "${extra_flags[@]}" "c/sokol_${package}.c"
    else
        "$EMCC_BIN" -c -g -DIMPL -D"${define}" "${extra_flags[@]}" "c/sokol_${package}.c"
    fi
    "$EMAR_BIN" rcs "$output" "sokol_${package}.o"
    rm -f "sokol_${package}.o"
}

build_backend() {
    local backend="$1"
    local define="$2"
    shift 2
    local extra_flags=("$@")
    local package

    for package in "${PACKAGES[@]}"; do
        build_variant "$package" "$backend" "$define" debug "${extra_flags[@]}"
        build_variant "$package" "$backend" "$define" release "${extra_flags[@]}"
    done
}

main() {
    build_backend gl SOKOL_GLES3
    build_backend wgpu SOKOL_WGPU --use-port=emdawnwebgpu
}

main "$@"
