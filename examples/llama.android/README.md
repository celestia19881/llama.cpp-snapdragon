# llama.android

Android app for running llama.cpp inference on-device. Built with Kotlin and Jetpack Compose.

## Requirements

- Android Studio Hedgehog (2023.1.1) or later
- JDK 17
- Android SDK with API level 36
- Minimum device API level: 33 (Android 13)

## Build

1. Open Android Studio and import this directory (`examples/llama.android`).
2. Wait for the Gradle sync to complete.
3. Build and run on a connected device or emulator.

Alternatively, build from the command line:

```sh
cd examples/llama.android
./gradlew build
```

## Features

- **GGUF Metadata Parsing** — Load and display model metadata via `GgufMetadataReader`.
- **Inference Engine** — Run inference through the `AiChat` facade with automatic prompt template formatting.
- **Token Streaming** — Collect generated tokens via Kotlin `Flow` for real-time display.

## Usage

1. Copy a GGUF model file to your device (e.g., via `adb push`).
2. Open the app and select the model file.
3. Enter a prompt and observe the generated output.

## Project Structure

```
llama.android/
├── app/             # Android application module
├── lib/             # Native library bindings
├── gradle/          # Gradle wrapper and version catalog
├── build.gradle.kts # Root build script
└── settings.gradle.kts
```

## CLI Alternative

For command-line usage on Android, see [docs/android.md](../../docs/android.md) for Termux and NDK cross-compilation instructions.

For Snapdragon-optimized builds (GPU/NPU acceleration), see [docs/snapdragon-quickstart.md](../../docs/snapdragon-quickstart.md).
