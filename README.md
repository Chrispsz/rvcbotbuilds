# RVCBotBuilds

[![CI](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml)

**ReVanced Magisk Module Builder** - Focado em YouTube e YouTube Music (ARM64-v8a)

## 📥 Downloads

Baixe os módulos e APKs mais recentes nas [Releases](https://github.com/Chrispsz/rvcbotbuilds/releases).

## ✨ Recursos

- ✅ **YouTube** - Módulo Magisk + APK Non-Root
- ✅ **YouTube Music** - Módulo Magisk + APK Non-Root
- 🚀 Focado exclusivamente em **ARM64-v8a** (dispositivos modernos)
- 📦 Atualizações automáticas via GitHub Actions
- 🔧 Suporte a Magisk e KernelSU

## 📱 Instalação

### Para usuários de Magisk/KernelSU (Root):
1. Baixe o módulo `.zip` da [última release](https://github.com/Chrispsz/rvcbotbuilds/releases)
2. Instale via Magisk/KernelSU Manager
3. Reinicie o dispositivo

### Para usuários Non-Root:
1. Baixe o APK da [última release](https://github.com/Chrispsz/rvcbotbuilds/releases)
2. Instale o [MicroG](https://github.com/ReVanced/GmsCore/releases) primeiro
3. Instale o APK do ReVanced

## 🔨 Build Local

### No Termux:
```bash
bash <(curl -sSf https://raw.githubusercontent.com/Chrispsz/rvcbotbuilds/main/build-termux.sh)
```

### No Desktop:
```bash
git clone https://github.com/Chrispsz/rvcbotbuilds
cd rvcbotbuilds
./build.sh
```

## ⚙️ Configuração

Edite o arquivo `config.toml` para personalizar os builds:

```toml
[YouTube]
enabled = true
build-mode = "both"  # "apk", "module" ou "both"
version = "auto"     # "auto", "latest", ou versão específica

[Music]
enabled = true
build-mode = "both"
version = "auto"
```

## 📋 Requisitos para Build

- Java 17+
- jq
- zip
- curl

## 🔗 Links Úteis

- [MicroG](https://github.com/ReVanced/GmsCore/releases) - Necessário para APKs non-root
- [zygisk-detach](https://github.com/j-hc/zygisk-detach) - Desanexar do Play Store
- [ReVanced Patches](https://github.com/ReVanced/revanced-patches)

## 📄 Licença

Este projeto é baseado no [revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module) de j-hc.

---

**Made with ❤️ by [Chrispsz](https://github.com/Chrispsz)**
