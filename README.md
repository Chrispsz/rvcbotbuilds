# RVCBot Builds

[![CI](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml/badge.svg)](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml)

Automated ReVanced builds with Magisk module support.

## Features

- 🤖 Automated daily builds (4PM UTC)
- 📦 arm64-v8a architecture optimized
- 🔄 ReVanced official patches
- 📱 YouTube APK + Magisk Module
- 🎵 YouTube Music APK

## Downloads

Get the latest builds from [Releases](https://github.com/Chrispsz/rvcbotbuilds/releases).

## Installation

### Non-Root (APK)
1. Install [GmsCore](https://github.com/ReVanced/GmsCore/releases)
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

## Requirements

- Java 17+
- jq
- zip
- curl

## Credits

- [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module) - Build system
- [ReVanced](https://github.com/ReVanced) - Patches & CLI

## License

GPL-3.0 License

---

Built with ❤️ by [Chrispsz](https://github.com/Chrispsz)
