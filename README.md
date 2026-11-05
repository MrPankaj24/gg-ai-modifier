# GG-AI Modifier

GG-AI Modifier is an Android game memory editor built with Flutter, Kotlin, and C++. It combines memory search, editing, freezing, Lua scripting, and AI-assisted workflows.

> **Disclaimer:** Use this tool only for education, research, and personal single-player games. Do not use it with online competitive games. Modifying game data may violate a game's terms of service.

## Features

- AI conversations with DeepSeek, OpenAI, Gemini, Xiaomi MiMo, and compatible APIs
- Exact, range, fuzzy, and AOB memory searches
- Read, write, freeze, batch operations, and bookmarks
- LuaJ scripting with a GG-compatible API
- Floating overlay mode for in-game access
- Markdown, LaTeX, Mermaid, and code highlighting in AI responses

## Requirements

- Android device with root access
- Flutter SDK 3.11.5 or newer compatible with the Dart constraint in `pubspec.yaml`
- Java 17 and Android SDK/NDK support for local builds

## Build and install

GitHub Actions builds an installable APK and an Android App Bundle on every push, pull request, and manual run. Open the completed workflow run, download the `gg-ai-modifier-android` artifact, and install `app-release.apk` on a compatible Android device.

Pushing a tag such as `v5.0.0` also publishes the APK and App Bundle in a GitHub release.

To build locally:

```bash
flutter pub get
flutter test
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

## Documentation

- [English technical documentation](README/v3.0.0-en_README.md)
- [Update history](update/)

## Donation

If this project is useful to you, donations are welcome.

**Binance USDT (TRC20):** `TXAgg43gZhE62VYHgBEaLt1WXVP8LNYEYP`

The repository retains the original donation images.
