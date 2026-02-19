# RVCBotBuilds

[![CI](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml)

**Builder de APKs ReVanced** - Focado em YouTube e YouTube Music (ARM64-v8a)

## 📥 Downloads

Baixe os APKs mais recentes nas [Releases](https://github.com/Chrispsz/rvcbotbuilds/releases).

## ✨ Recursos

| App | APK Non-Root |
|-----|--------------|
| 📺 YouTube | ✅ |
| 🎵 YouTube Music | ✅ |

### 🎯 Características:
- 🚀 Focado exclusivamente em **ARM64-v8a** (dispositivos modernos)
- 📦 Atualizações automáticas quando há novos patches (verificação diária às 13:00 BR)
- 📢 Notificações automáticas no Telegram
- ⚡ Build otimizada (~2 minutos)

## 📱 Instalação

### Para usuários Non-Root:
1. Instale o [MicroG](https://github.com/ReVanced/GmsCore/releases) primeiro
2. Baixe o APK da [última release](https://github.com/Chrispsz/rvcbotbuilds/releases)
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
build-mode = "apk"       # Apenas APK (non-root)
version = "auto"         # "auto", "latest", ou versão específica

[Music]
enabled = true
build-mode = "apk"
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
<summary><b>Por que apenas APKs?</b></summary>

Este projeto é focado em usuários sem root. Para usar, basta instalar o MicroG e o APK do ReVanced. Se você tem root e prefere módulos Magisk, use o projeto original [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module).

</details>

<details>
<summary><b>Por que apenas ARM64-v8a?</b></summary>

A maioria dos smartphones modernos usa ARM64. Isso reduz o tamanho dos builds e mantém o projeto mais limpo. Se você tem um dispositivo ARM32 (antigo), use o projeto original [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module).

</details>

<details>
<summary><b>Quando são geradas novas builds?</b></summary>

O sistema verifica diariamente (13:00 horário de Brasília) se há novos patches do ReVanced. Se houver, uma nova build é gerada automaticamente.

</details>

## 📄 Licença

Este projeto é um fork de [revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module) de j-hc.

---

**Feito com ❤️ por [Chrispsz](https://github.com/Chrispsz)**
