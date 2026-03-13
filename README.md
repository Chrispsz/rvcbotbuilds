# RVC Bot Builds

[![CI](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml/badge.svg)](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml)

Automated build pipeline for ReVanced and Morphe APKs with CI/CD integration.

## Features

- 🤖 Automated daily builds (4PM UTC)
- 📦 ARM64-v8a architecture optimized
- 🔄 Dual patch sources: ReVanced + Morphe
- 🔔 Telegram notifications
- ⚡ Optimized build process

## What's Built

| App | Type | Patches |
|-----|------|---------|
| YouTube | APK + Module | ReVanced |
| YouTube | APK + Module | Morphe |
| YouTube Music | APK | ReVanced |

## Downloads

Get the latest builds from [Releases](https://github.com/Chrispsz/rvcbotbuilds/releases).

## Installation

### Non-Root (APK)
1. Install [MicroG/GmsCore](https://github.com/ReVanced/GmsCore/releases)
2. Download APK from releases
3. Install on your device

### Root (Magisk Module)
1. Download module zip from releases
2. Flash in Magisk
3. Reboot

## Build Locally

### Termux (Android)
```bash
bash <(curl -sSf https://raw.githubusercontent.com/Chrispsz/rvcbotbuilds/main/build-termux.sh)
```

### Desktop (Linux)
```bash
git clone https://github.com/Chrispsz/rvcbotbuilds
cd rvcbotbuilds
./build.sh
```

## Configuration

Edit `config.toml` to customize builds:

```toml
[YouTube]
build-mode = "both"        # "apk", "module", or "both"
arch = "arm64-v8a"         # Architecture
version = "auto"           # "auto", "latest", or specific version

[YouTube-Morphe]
patches-source = "MorpheApp/morphe-patches"
cli-source = "MorpheApp/morphe-cli"
rv-brand = "Morphe"
```

## Requirements

- Java 17+
- jq
- zip
- curl

## Credits

- [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module) - Build system
- [ReVanced](https://github.com/ReVanced) - Patches & CLI
- [MorpheApp](https://github.com/MorpheApp) - Morphe patches

## License

GPL-3.0 License

---

Built with ❤️ by [Chrispsz](https://github.com/Chrispsz)
