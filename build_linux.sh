#!/usr/bin/env sh
set -eu

cc_bin=${CC:-cc}
linux_host=$(uname -s)
linux_machine=$(uname -m)

if [ "$linux_host" != "Linux" ]; then
    echo "build_linux.sh must run on Linux (host is $linux_host)" >&2
    exit 1
fi

arch_value=${SOKOL_ARCH:-$linux_machine}
case "$arch_value" in
    x86_64|amd64|x64)
        arch_suffix=x64
        ;;
    aarch64|arm64)
        arch_suffix=arm64
        ;;
    *)
        echo "unsupported linux arch: $arch_value (host machine: $linux_machine)" >&2
        echo "set SOKOL_ARCH=x64 or SOKOL_ARCH=arm64 to override" >&2
        exit 1
        ;;
esac

echo "linux host: $linux_machine, cc: $cc_bin, artifact arch: $arch_suffix"

build_lib_release() {
    src=$1
    dst=$2
    backend=$3
    libs=${4-}
    echo "$dst"
    # static
    "$cc_bin" -pthread -c -O2 -DNDEBUG -DIMPL -D"$backend" "c/$src.c"
    ar rcs "$dst.a" "$src.o"
    # shared
    "$cc_bin" -pthread -shared -O2 -fPIC -DNDEBUG -DIMPL -D"$backend" -o "$dst.so" "c/$src.c" $libs
}

build_lib_debug() {
    src=$1
    dst=$2
    backend=$3
    libs=${4-}
    echo "$dst"
    # static
    "$cc_bin" -pthread -c -g -DIMPL -D"$backend" "c/$src.c"
    ar rcs "$dst.a" "$src.o"
    # shared
    "$cc_bin" -pthread -shared -g -fPIC -DIMPL -D"$backend" -o "$dst.so" "c/$src.c" $libs
}

# Linux + GL + Release
build_lib_release sokol_log "log/sokol_log_linux_${arch_suffix}_gl_release" SOKOL_GLCORE
build_lib_release sokol_gfx "gfx/sokol_gfx_linux_${arch_suffix}_gl_release" SOKOL_GLCORE
build_lib_release sokol_app "app/sokol_app_linux_${arch_suffix}_gl_release" SOKOL_GLCORE
build_lib_release sokol_glue "glue/sokol_glue_linux_${arch_suffix}_gl_release" SOKOL_GLCORE
build_lib_release sokol_time "time/sokol_time_linux_${arch_suffix}_gl_release" SOKOL_GLCORE
build_lib_release sokol_audio "audio/sokol_audio_linux_${arch_suffix}_gl_release" SOKOL_GLCORE "-lasound"
build_lib_release sokol_debugtext "debugtext/sokol_debugtext_linux_${arch_suffix}_gl_release" SOKOL_GLCORE
build_lib_release sokol_shape "shape/sokol_shape_linux_${arch_suffix}_gl_release" SOKOL_GLCORE
build_lib_release sokol_gl "gl/sokol_gl_linux_${arch_suffix}_gl_release" SOKOL_GLCORE

# Linux + GL + Debug
build_lib_debug sokol_log "log/sokol_log_linux_${arch_suffix}_gl_debug" SOKOL_GLCORE
build_lib_debug sokol_gfx "gfx/sokol_gfx_linux_${arch_suffix}_gl_debug" SOKOL_GLCORE
build_lib_debug sokol_app "app/sokol_app_linux_${arch_suffix}_gl_debug" SOKOL_GLCORE
build_lib_debug sokol_glue "glue/sokol_glue_linux_${arch_suffix}_gl_debug" SOKOL_GLCORE
build_lib_debug sokol_time "time/sokol_time_linux_${arch_suffix}_gl_debug" SOKOL_GLCORE
build_lib_debug sokol_audio "audio/sokol_audio_linux_${arch_suffix}_gl_debug" SOKOL_GLCORE "-lasound"
build_lib_debug sokol_debugtext "debugtext/sokol_debugtext_linux_${arch_suffix}_gl_debug" SOKOL_GLCORE
build_lib_debug sokol_shape "shape/sokol_shape_linux_${arch_suffix}_gl_debug" SOKOL_GLCORE
build_lib_debug sokol_gl "gl/sokol_gl_linux_${arch_suffix}_gl_debug" SOKOL_GLCORE

# Linux + Vulkan + Release
build_lib_release sokol_gfx "gfx/sokol_gfx_linux_${arch_suffix}_vulkan_release" SOKOL_VULKAN "-lvulkan"

# Linux + Vulkan + Debug
build_lib_debug sokol_gfx "gfx/sokol_gfx_linux_${arch_suffix}_vulkan_debug" SOKOL_VULKAN "-lvulkan"

rm -f ./*.o
