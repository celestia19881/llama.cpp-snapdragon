# Snapdragon Android Quickstart

Step-by-step guide for building llama.cpp on a remote Linux server and deploying to an Android device with a Snapdragon chip.

For more details on individual topics, see:
- [Android build options](android.md)
- [Snapdragon backend setup](backend/snapdragon/README.md)
- [OpenCL backend (Adreno GPU)](backend/OPENCL.md)
- [Hexagon backend internals](backend/snapdragon/developer.md)
- [General build instructions](build.md)

## Prerequisites

### Remote Server

- Linux x86_64 host (Ubuntu 20.04+ recommended)
- Docker (for the Snapdragon toolchain image) **or** Android NDK r28b+ installed manually
- ADB (Android Debug Bridge) installed on the host
- At least 10 GB of free disk space

### Android Device

- Snapdragon-based phone with USB debugging enabled
  - See https://developer.android.com/studio/debug/dev-options
- USB connection (or network ADB) between server and device

### Supported Snapdragon Backends

| Backend | Hardware | Use Case |
|---------|----------|----------|
| CPU | ARM Cortex cores | Universal fallback |
| OpenCL (Adreno GPU) | Adreno 750, 830, X85 | GPU-accelerated inference |
| Hexagon (NPU) | HTP v73, v75, v79, v81 | NPU-accelerated inference |

## Step 1: Clone the Repository

```sh
git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp
```

## Step 2: Set Up the Build Environment

### Option A: Docker Toolchain (Recommended)

The Snapdragon toolchain Docker image bundles the Android NDK, OpenCL SDK, Hexagon SDK, CMake, and Ninja.

```sh
docker run -it -u $(id -u):$(id -g) \
  --volume $(pwd):/workspace \
  --platform linux/amd64 \
  ghcr.io/snapdragon-toolchain/arm64-android:v0.3
```

Inside the container:

```sh
cd /workspace
```

### Option B: Manual NDK Setup

Install the Android NDK and set `ANDROID_NDK_ROOT`:

```sh
export ANDROID_NDK_ROOT=/path/to/android-ndk-r28b
```

Then install OpenCL headers and ICD loader (required for GPU backend):

```sh
# Install OpenCL headers
git clone https://github.com/KhronosGroup/OpenCL-Headers
cp -r OpenCL-Headers/CL $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include

# Install CL C++ headers
git clone https://github.com/KhronosGroup/OpenCL-CLHPP
cp -r OpenCL-CLHPP/include/CL/* $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/CL

# Build and install ICD loader
git clone https://github.com/KhronosGroup/OpenCL-ICD-Loader
cd OpenCL-ICD-Loader
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake \
  -DOPENCL_ICD_LOADER_HEADERS_DIR=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=31 -DANDROID_STL=c++_shared
cmake --build build
cp build/libOpenCL.so $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android
cd ..
```

For Hexagon NPU support, install the Hexagon SDK (adjust version numbers to match your installation):

```sh
export HEXAGON_SDK_ROOT=/path/to/hexagon-sdk/6.4.0.2
export HEXAGON_TOOLS_ROOT=$HEXAGON_SDK_ROOT/tools/HEXAGON_Tools/19.0.04
```

## Step 3: Verify the Environment

Run the environment check script to ensure all required tools are present:

```sh
./scripts/snapdragon/check-env.sh
```

## Step 4: Build

Copy the CMake presets and build:

```sh
cp docs/backend/snapdragon/CMakeUserPresets.json .

cmake --preset arm64-android-snapdragon-release -B build-snapdragon
cmake --build build-snapdragon
```

Create an installable package:

```sh
cmake --install build-snapdragon --prefix pkg-snapdragon/llama.cpp
```

### CPU-Only Build (Without Snapdragon-Specific Backends)

If you only need the CPU backend (no OpenCL or Hexagon SDKs required):

```sh
cmake \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-28 \
  -DCMAKE_C_FLAGS="-march=armv8.7a" \
  -DCMAKE_CXX_FLAGS="-march=armv8.7a" \
  -DGGML_OPENMP=OFF \
  -DGGML_LLAMAFILE=OFF \
  -B build-android

cmake --build build-android --config Release
cmake --install build-android --prefix pkg-android/llama.cpp
```

## Step 5: Download a Model

```sh
wget https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_0.gguf
```

See [OpenCL backend docs](backend/OPENCL.md) for quantization recommendations per Snapdragon variant.

## Step 6: Deploy to the Device

> **Note:** ADB must be run from the host, not from inside the Docker container.

```sh
# Push the built package
adb push pkg-snapdragon/llama.cpp /data/local/tmp/

# Create a directory for models and push the model
adb shell "mkdir -p /data/local/tmp/gguf"
adb push Llama-3.2-1B-Instruct-Q4_0.gguf /data/local/tmp/gguf/
```

## Step 7: Run on the Device

### Using Helper Scripts

The repo provides wrapper scripts for common tasks via ADB:

```sh
# Run a completion (NPU backend)
M=Llama-3.2-1B-Instruct-Q4_0.gguf D=HTP0 ./scripts/snapdragon/adb/run-completion.sh \
  -p "what is the most popular cookie in the world?"

# Run a benchmark (NPU backend)
M=Llama-3.2-1B-Instruct-Q4_0.gguf ./scripts/snapdragon/adb/run-bench.sh -p 128 -n 64

# Run with GPU (OpenCL/Adreno) backend
M=Llama-3.2-1B-Instruct-Q4_0.gguf D=GPUOpenCL ./scripts/snapdragon/adb/run-completion.sh \
  -p "hello world"

# Run with CPU only
M=Llama-3.2-1B-Instruct-Q4_0.gguf D=none ./scripts/snapdragon/adb/run-completion.sh \
  -p "hello world"
```

#### Script Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `M` | Model filename | `Llama-3.2-3B-Instruct-Q4_0.gguf` |
| `D` | Device/backend (`HTP0`, `GPUOpenCL`, `none`) | `HTP0` |
| `S` | ADB device serial (for multiple devices) | — |
| `H` | ADB host | — |
| `NDEV` | Number of Hexagon sessions (for large models) | `1` |
| `V` | Verbose logging | — |
| `E` | Enable experimental features | — |

### Manual ADB Shell

```sh
adb shell
cd /data/local/tmp/llama.cpp
LD_LIBRARY_PATH=lib ADSP_LIBRARY_PATH=lib \
  ./bin/llama-cli --no-mmap -m /data/local/tmp/gguf/Llama-3.2-1B-Instruct-Q4_0.gguf \
    -t 6 --cpu-mask 0xfc --ctx-size 4096 -ngl 99 --device HTP0 \
    -p "what is the most popular cookie in the world?"
```

## Troubleshooting

### ADB Cannot Connect

- Verify USB debugging is enabled: **Settings → Developer options → USB debugging**
- Check connection: `adb devices` should list your device
- For network ADB: `adb connect <device-ip>:5555`

### Build Fails with Missing Toolchain

- Ensure `ANDROID_NDK_ROOT` points to a valid NDK installation
- Inside Docker, the toolchain file is at `/opt/android-ndk-r28b/build/cmake/android.toolchain.cmake`

### Hexagon Libraries Not Loading

- Ensure `ADSP_LIBRARY_PATH` is set when running on the device
- Check that HTP libraries (`libggml-htp-v*.so`) are present in `lib/`
- Verify your device's Hexagon architecture version matches available libraries

### Out of Memory

- Use smaller models or stronger quantization (e.g., Q4_0)
- Reduce context size with `--ctx-size`
- For large models (>4B parameters), use multi-session mode: `NDEV=2 D=HTP0,HTP1`
- Each Hexagon session has a 3.5 GB limit

### OpenCL Backend Errors

- Ensure the device has a compatible Adreno GPU driver
- Use `--device GPUOpenCL` to select the GPU backend
- See [OpenCL docs](backend/OPENCL.md) for supported devices and quantizations
