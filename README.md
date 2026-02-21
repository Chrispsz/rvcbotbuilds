# RVC Bot Builds

[![CI](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml/badge.svg)](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml)

Automated build pipeline for Android APK compilation with CI/CD integration.

## Features

- 🤖 Automated daily builds
- 📦 Multi-architecture support (ARM64-v8a)
- 🔔 Telegram notifications
- ⚡ Optimized build process (~2 minutes)
- 📋 Customizable configuration

## Downloads

Get the latest builds from [Releases](https://github.com/Chrispsz/rvcbotbuilds/releases).

## Installation

1. Install required dependencies (MicroG for non-root)
2. Download APK from releases
3. Install on your device

## Build Locally

### Termux (Android)
```bash
bash <(curl -sSf https://raw.githubusercontent.com/Chrispsz/rvcbotbuilds/main/build-termux.sh)
```

### Desktop (Linux/Windows)
```bash
git clone https://github.com/Chrispsz/rvcbotbuilds
cd rvcbotbuilds
./build.sh
```

## Configuration

Edit `config.toml` to customize builds:

```toml
[App]
enabled = true
build-mode = "apk"
version = "auto"  # "auto", "latest", or specific version
```

## Requirements

- Java 17+
- jq
- zip
- curl

## Tech Stack

| Tool | Purpose |
|------|---------|
| GitHub Actions | CI/CD pipeline |
| Shell | Build scripts |
| jq | JSON processing |
| curl | HTTP requests |

## License

GPL-3.0 License

---

Built with ❤️ by [Chrispsz](https://github.com/Chrispsz)
