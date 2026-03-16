#!/bin/sh
#
# Check that the build environment is properly configured for
# cross-compiling llama.cpp for Android on Snapdragon devices.
#
# Usage: ./scripts/snapdragon/check-env.sh
#

set -e

ok=0
warn=0
fail=0

pass() { ok=$((ok + 1));   printf "  [\033[32mOK\033[0m]   %s\n" "$1"; }
skip() { warn=$((warn + 1)); printf "  [\033[33mSKIP\033[0m] %s\n" "$1"; }
err()  { fail=$((fail + 1)); printf "  [\033[31mFAIL\033[0m] %s\n" "$1"; }

echo ""
echo "=== llama.cpp Snapdragon Build Environment Check ==="
echo ""

# ---- CMake ----
printf "Checking CMake... "
if command -v cmake >/dev/null 2>&1; then
    cmake_ver=$(cmake --version | head -1)
    pass "$cmake_ver"
else
    err "cmake not found"
fi

# ---- Ninja ----
printf "Checking Ninja... "
if command -v ninja >/dev/null 2>&1; then
    ninja_ver=$(ninja --version 2>/dev/null || echo "unknown")
    pass "ninja $ninja_ver"
else
    skip "ninja not found (optional but recommended)"
fi

# ---- Android NDK ----
printf "Checking Android NDK... "
if [ -n "$ANDROID_NDK_ROOT" ] && [ -d "$ANDROID_NDK_ROOT" ]; then
    tc="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake"
    if [ -f "$tc" ]; then
        pass "ANDROID_NDK_ROOT=$ANDROID_NDK_ROOT"
    else
        err "ANDROID_NDK_ROOT is set but toolchain file not found: $tc"
    fi
elif [ -n "$ANDROID_NDK" ] && [ -d "$ANDROID_NDK" ]; then
    pass "ANDROID_NDK=$ANDROID_NDK (consider also setting ANDROID_NDK_ROOT)"
else
    err "ANDROID_NDK_ROOT is not set or directory does not exist"
fi

# ---- OpenCL SDK ----
printf "Checking OpenCL headers... "
if [ -n "$ANDROID_NDK_ROOT" ]; then
    cl_header="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/CL/cl.h"
    if [ -f "$cl_header" ]; then
        pass "found at $cl_header"
    else
        skip "OpenCL headers not found (needed for GPU backend)"
    fi
elif [ -n "$OPENCL_SDK_ROOT" ]; then
    pass "OPENCL_SDK_ROOT=$OPENCL_SDK_ROOT"
else
    skip "OpenCL headers not checked (ANDROID_NDK_ROOT not set)"
fi

printf "Checking OpenCL ICD loader... "
if [ -n "$ANDROID_NDK_ROOT" ]; then
    cl_lib="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libOpenCL.so"
    if [ -f "$cl_lib" ]; then
        pass "found at $cl_lib"
    else
        skip "libOpenCL.so not found (needed for GPU backend)"
    fi
else
    skip "OpenCL ICD loader not checked (ANDROID_NDK_ROOT not set)"
fi

# ---- Hexagon SDK ----
printf "Checking Hexagon SDK... "
if [ -n "$HEXAGON_SDK_ROOT" ] && [ -d "$HEXAGON_SDK_ROOT" ]; then
    pass "HEXAGON_SDK_ROOT=$HEXAGON_SDK_ROOT"
else
    skip "HEXAGON_SDK_ROOT is not set (needed for NPU backend)"
fi

printf "Checking Hexagon Tools... "
if [ -n "$HEXAGON_TOOLS_ROOT" ] && [ -d "$HEXAGON_TOOLS_ROOT" ]; then
    pass "HEXAGON_TOOLS_ROOT=$HEXAGON_TOOLS_ROOT"
else
    skip "HEXAGON_TOOLS_ROOT is not set (needed for NPU backend)"
fi

# ---- ADB ----
printf "Checking ADB... "
if command -v adb >/dev/null 2>&1; then
    adb_ver=$(adb version 2>/dev/null | head -1)
    pass "$adb_ver"

    printf "Checking ADB device connectivity... "
    devices=$(adb devices 2>/dev/null | grep -c 'device$' || true)
    if [ "$devices" -gt 0 ]; then
        pass "$devices device(s) connected"
    else
        skip "no devices connected (connect a device for deployment)"
    fi
else
    skip "adb not found (needed for on-device deployment)"
fi

# ---- Docker (optional) ----
printf "Checking Docker... "
if command -v docker >/dev/null 2>&1; then
    docker_ver=$(docker --version 2>/dev/null)
    pass "$docker_ver"
else
    skip "docker not found (optional, for toolchain image)"
fi

# ---- CMake presets ----
printf "Checking CMakeUserPresets.json... "
script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root="$script_dir/../.."
if [ -f "$repo_root/CMakeUserPresets.json" ]; then
    pass "found in project root"
else
    skip "not found — run: cp docs/backend/snapdragon/CMakeUserPresets.json ."
fi

# ---- Summary ----
echo ""
echo "=== Summary: $ok passed, $warn skipped, $fail failed ==="
echo ""

if [ "$fail" -gt 0 ]; then
    echo "Some required tools are missing. Please install them before building."
    echo "See docs/snapdragon-quickstart.md for setup instructions."
    exit 1
fi

if [ "$warn" -gt 0 ]; then
    echo "Some optional components are not available."
    echo "The CPU backend will work; GPU and NPU backends require additional setup."
fi

exit 0
