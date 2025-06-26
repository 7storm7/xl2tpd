#!/bin/bash

set -e

# --- Help Message ---
if [[ "$1" == "--help" ]]; then
    echo "Usage: $0 --ndk-path PATH --api-level LEVEL --source-dir PATH"
    echo ""
    echo "All options are required:"
    echo "  --ndk-path PATH       Path to Android NDK"
    echo "  --api-level LEVEL     Android API level (e.g., 29)"
    echo "  --source-dir PATH     Path to xl2tpd source directory"
    echo ""
    exit 0
fi

PRODUCED_BINARY_NAME="xl2tpd"

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ndk-path) NDK_PATH="$2"; shift 2 ;;
        --api-level) API_LEVEL="$2"; shift 2 ;;
        --source-dir) XL2TPD_SOURCE_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Validate Required Inputs ---
if [[ -z "$NDK_PATH" || -z "$API_LEVEL" || -z "$XL2TPD_SOURCE_DIR" ]]; then
    echo "Error: Missing required arguments."
    echo "Run with --help for usage."
    exit 1
fi

BUILD_OUTPUT_ROOT="${XL2TPD_SOURCE_DIR}/build_xl2tpd_android_binaries"

# --- Validate Paths ---
if [ ! -d "$NDK_PATH" ]; then
    echo "Error: NDK directory not found at '$NDK_PATH'"
    exit 1
fi

if [ ! -d "$XL2TPD_SOURCE_DIR" ]; then
    echo "Error: xl2tpd source directory not found at '$XL2TPD_SOURCE_DIR'"
    exit 1
fi

mkdir -p "$BUILD_OUTPUT_ROOT"

# --- Function to Build for an Architecture ---
build_arch() {
    local ARCH=$1
    local TARGET_TRIPLE=$2

    echo "----------------------------------------------------"
    echo "Building for: $ARCH"
    echo "----------------------------------------------------"

    local ARCH_OUTPUT_DIR="${BUILD_OUTPUT_ROOT}/${ARCH}"
    mkdir -p "$ARCH_OUTPUT_DIR"

    export TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
    export CC="$TOOLCHAIN/bin/${TARGET_TRIPLE}${API_LEVEL}-clang"
    export CFLAGS="--sysroot=$TOOLCHAIN/sysroot -fPIC -DUSE_MODERN_PTY"

    if [ ! -f "$CC" ]; then
        echo "Error: Compiler not found at $CC"
        exit 1
    fi

    cd "$XL2TPD_SOURCE_DIR"
    make clean
    make ANDROID_BUILD=1 CC="$CC" CFLAGS="$CFLAGS"

    if [ -f "$PRODUCED_BINARY_NAME" ]; then
        cp "$PRODUCED_BINARY_NAME" "$ARCH_OUTPUT_DIR/"
    elif [ -f "src/$PRODUCED_BINARY_NAME" ]; then
        cp "src/$PRODUCED_BINARY_NAME" "$ARCH_OUTPUT_DIR/"
    else
        echo "Error: '$PRODUCED_BINARY_NAME' not found after build."
        exit 1
    fi

    echo "$ARCH binary copied to $ARCH_OUTPUT_DIR/"
}

# --- Build Targets ---
build_arch "x86_64" "x86_64-linux-android"
build_arch "arm64" "aarch64-linux-android"

echo "----------------------------------------------------"
echo "All builds completed."
echo "Binaries are located in:"
echo "  ${BUILD_OUTPUT_ROOT}/x86_64/$(basename "$PRODUCED_BINARY_NAME")"
echo "  ${BUILD_OUTPUT_ROOT}/arm64/$(basename "$PRODUCED_BINARY_NAME")"
echo "----------------------------------------------------"

exit 0
