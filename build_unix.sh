#!/usr/bin/env sh

set -eu

MODE=${1-}
if [ -z "$MODE" ]; then
    echo "usage: build_unix.sh <shared|static>" >&2
    exit 1
fi
shift

case "$MODE" in
    shared | static) ;;
    *)
        echo "unsupported mode: $MODE" >&2
        exit 1
        ;;
esac

HOST_OS=$(uname -s)
HOST_ARCH=$(uname -m)
CC_BIN=${CC:-cc}
PACKAGES="log app gfx glue time audio debugtext shape gl"

arch_suffix() {
    case "$HOST_ARCH" in
        x86_64 | amd64 | x64) echo "x64" ;;
        aarch64 | arm64) echo "arm64" ;;
        *)
            echo "unsupported host arch: $HOST_ARCH" >&2
            exit 1
            ;;
    esac
}

host_arch_dir() {
    suffix=$(arch_suffix)
    case "$HOST_OS" in
        Darwin) echo "darwin_${suffix}" ;;
        Linux) echo "linux_${suffix}" ;;
        *)
            echo "unsupported host: $HOST_OS" >&2
            exit 1
            ;;
    esac
}

clang_arch() {
    case "$(arch_suffix)" in
        x64) echo "x86_64" ;;
        arm64) echo "arm64" ;;
    esac
}

linux_static_output() {
    package=$1
    backend=$2
    config=$3
    suffix=$(arch_suffix)
    echo "${package}/linux_${suffix}/sokol_${package}_linux_${suffix}_${backend}_${config}"
}

linux_shared_output() {
    linux_static_output "$@"
}

darwin_static_output() {
    package=$1
    backend=$2
    config=$3
    suffix=$(arch_suffix)
    echo "${package}/darwin_${suffix}/sokol_${package}_macos_${suffix}_${backend}_${config}"
}

darwin_shared_output() {
    backend=$1
    config=$2
    suffix=$(arch_suffix)
    echo "darwin_${suffix}/sokol_dylib_macos_${suffix}_${backend}_${config}"
}

build_linux_static_variant() {
    package=$1
    backend_name=$2
    backend_define=$3
    config=$4
    output=$(linux_static_output "$package" "$backend_name" "$config")
    echo "$output"
    mkdir -p "$(dirname "$output")"
    if [ "$config" = "release" ]; then
        "$CC_BIN" -pthread -c -O2 -DNDEBUG -DIMPL -D"$backend_define" "c/sokol_${package}.c"
    else
        "$CC_BIN" -pthread -c -g -DIMPL -D"$backend_define" "c/sokol_${package}.c"
    fi
    ar rcs "${output}.a" "sokol_${package}.o"
    rm -f "sokol_${package}.o"
}

build_linux_shared_variant() {
    package=$1
    backend_name=$2
    backend_define=$3
    config=$4
    extra_libs=${5-}
    output=$(linux_shared_output "$package" "$backend_name" "$config")
    echo "$output"
    mkdir -p "$(dirname "$output")"
    if [ "$config" = "release" ]; then
        "$CC_BIN" -pthread -shared -O2 -fPIC -DNDEBUG -DIMPL -D"$backend_define" -o "${output}.so" "c/sokol_${package}.c" $extra_libs
    else
        "$CC_BIN" -pthread -shared -g -fPIC -DIMPL -D"$backend_define" -o "${output}.so" "c/sokol_${package}.c" $extra_libs
    fi
}

build_darwin_static_variant() {
    package=$1
    backend_name=$2
    backend_define=$3
    config=$4
    output=$(darwin_static_output "$package" "$backend_name" "$config")
    echo "$output"
    mkdir -p "$(dirname "$output")"
    if [ "$config" = "release" ]; then
        MACOSX_DEPLOYMENT_TARGET=10.13 clang -c -O2 -x objective-c -arch "$(clang_arch)" -DNDEBUG -DIMPL -D"$backend_define" "c/sokol_${package}.c"
    else
        MACOSX_DEPLOYMENT_TARGET=10.13 clang -c -g -x objective-c -arch "$(clang_arch)" -DIMPL -D"$backend_define" "c/sokol_${package}.c"
    fi
    ar rcs "${output}.a" "sokol_${package}.o"
    rm -f "sokol_${package}.o"
}

build_darwin_shared_variant() {
    backend_name=$1
    backend_define=$2
    config=$3
    output=$(darwin_shared_output "$backend_name" "$config")
    echo "$output"
    mkdir -p "$(dirname "$output")"
    if [ "$config" = "release" ]; then
        MACOSX_DEPLOYMENT_TARGET=10.13 clang -c -O2 -x objective-c -arch "$(clang_arch)" -DNDEBUG -DIMPL -D"$backend_define" c/sokol.c
    else
        MACOSX_DEPLOYMENT_TARGET=10.13 clang -c -g -x objective-c -arch "$(clang_arch)" -DIMPL -D"$backend_define" c/sokol.c
    fi

    if [ "$backend_define" = "SOKOL_METAL" ]; then
        clang -dynamiclib -arch "$(clang_arch)" \
            -framework Foundation \
            -framework CoreGraphics \
            -framework Cocoa \
            -framework QuartzCore \
            -framework CoreAudio \
            -framework AudioToolbox \
            -framework Metal \
            -framework MetalKit \
            -install_name "$(basename "$output").dylib" \
            -o "${output}.dylib" sokol.o
    else
        clang -dynamiclib -arch "$(clang_arch)" \
            -framework Foundation \
            -framework CoreGraphics \
            -framework Cocoa \
            -framework QuartzCore \
            -framework CoreAudio \
            -framework AudioToolbox \
            -framework OpenGL \
            -install_name "$(basename "$output").dylib" \
            -o "${output}.dylib" sokol.o
    fi
    rm -f sokol.o
}

build_linux_static() {
    for package in $PACKAGES; do
        build_linux_static_variant "$package" gl SOKOL_GLCORE release
        build_linux_static_variant "$package" gl SOKOL_GLCORE debug
    done
    build_linux_static_variant gfx vulkan SOKOL_VULKAN release
    build_linux_static_variant gfx vulkan SOKOL_VULKAN debug
}

build_linux_shared() {
    for package in $PACKAGES; do
        extra_libs=
        if [ "$package" = "audio" ]; then
            extra_libs="-lasound"
        fi
        build_linux_shared_variant "$package" gl SOKOL_GLCORE release "$extra_libs"
        build_linux_shared_variant "$package" gl SOKOL_GLCORE debug "$extra_libs"
    done
    build_linux_shared_variant gfx vulkan SOKOL_VULKAN release "-lvulkan"
    build_linux_shared_variant gfx vulkan SOKOL_VULKAN debug "-lvulkan"
}

build_darwin_static() {
    for package in $PACKAGES; do
        build_darwin_static_variant "$package" metal SOKOL_METAL release
        build_darwin_static_variant "$package" metal SOKOL_METAL debug
        build_darwin_static_variant "$package" gl SOKOL_GLCORE release
        build_darwin_static_variant "$package" gl SOKOL_GLCORE debug
    done
}

build_darwin_shared() {
    build_darwin_shared_variant metal SOKOL_METAL release
    build_darwin_shared_variant metal SOKOL_METAL debug
    build_darwin_shared_variant gl SOKOL_GLCORE release
    build_darwin_shared_variant gl SOKOL_GLCORE debug
}

main() {
    case "$HOST_OS" in
        Linux)
            if [ "$MODE" = "shared" ]; then
                build_linux_shared
            else
                build_linux_static
            fi
            ;;
        Darwin)
            if [ "$MODE" = "shared" ]; then
                build_darwin_shared
            else
                build_darwin_static
            fi
            ;;
        *)
            echo "unsupported host: $HOST_OS" >&2
            exit 1
            ;;
    esac
}

main "$@"
