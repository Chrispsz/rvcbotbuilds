# RVCBotBuilds

[![CI](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml)

**Builder de Módulos Magisk ReVanced** - Focado em YouTube e YouTube Music (ARM64-v8a)

## 📥 Downloads

Baixe os módulos e APKs mais recentes nas [Releases](https://github.com/Chrispsz/rvcbotbuilds/releases).

## ✨ Recursos

| App | Módulo Magisk | APK Non-Root |
|-----|---------------|--------------|
| 📺 YouTube | ✅ | ✅ |
| 🎵 YouTube Music | ✅ | ✅ |

### 🎯 Características:
- 🚀 Focado exclusivamente em **ARM64-v8a** (dispositivos modernos)
- 📦 Atualizações automáticas via GitHub Actions (diariamente às 13:00 BR)
- 🔧 Suporte a **Magisk** e **KernelSU**
- 📢 Notificações automáticas no Telegram

## 📱 Instalação

### Para usuários Root (Magisk/KernelSU):
1. Baixe o módulo `.zip` da [última release](https://github.com/Chrispsz/rvcbotbuilds/releases)
2. Instale via Magisk/KernelSU Manager
3. Reinicie o dispositivo

### Para usuários Non-Root:
1. Baixe o APK da [última release](https://github.com/Chrispsz/rvcbotbuilds/releases)
2. Instale o [MicroG](https://github.com/ReVanced/GmsCore/releases) primeiro
3. Instale o APK do ReVanced

## 🔨 Build Local

### No Termux (Android):
```bash
bash <(curl -sSf https://raw.githubusercontent.com/Chrispsz/rvcbotbuilds/main/build-termux.sh)
```

### No Desktop (Linux/Windows):
```bash
git clone https://github.com/Chrispsz/rvcbotbuilds
cd rvcbotbuilds
./build.sh
```

## ⚙️ Configuração

Edite o arquivo `config.toml` para personalizar:

```toml
[YouTube]
enabled = true           # Habilitar/desabilitar
build-mode = "both"      # "apk", "module" ou "both"
version = "auto"         # "auto", "latest", ou versão específica

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

| Recurso | Link |
|---------|------|
| 📱 MicroG | [ReVanced/GmsCore](https://github.com/ReVanced/GmsCore/releases) |
| 🔓 Zygisk Detach | [j-hc/zygisk-detach](https://github.com/j-hc/zygisk-detach) |
| 🔧 Patches Originais | [ReVanced/revanced-patches](https://github.com/ReVanced/revanced-patches) |
| 🤖 Bot Telegram | Use `!youtube` ou `!rvcbot` |

## ❓ FAQ

<details>
<summary><b>Qual a diferença entre Módulo e APK?</b></summary>

- **Módulo Magisk**: Para dispositivos com root. O app original é substituído automaticamente.
- **APK Non-Root**: Para dispositivos sem root. Requer instalação do MicroG para funcionar.

</details>

<details>
<summary><b>Por que apenas ARM64-v8a?</b></summary>

A maioria dos smartphones modernos usa ARM64. Isso reduz o tamanho dos builds e mantém o projeto mais limpo. Se você tem um dispositivo ARM32 (antigo), use o projeto original [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module).

</details>

<details>
<summary><b>Como recebo notificações de novas builds?</b></summary>

Entre no canal/grupo do Telegram onde o bot está configurado. Use `!youtube` ou `!rvcbot` para ver a última release.

</details>

## 📄 Licença

Este projeto é um fork de [revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module) de j-hc.

---

**Feito com ❤️ por [Chrispsz](https://github.com/Chrispsz)**
