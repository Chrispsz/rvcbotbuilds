<div align="center">

# 📸🎬🎵 RVCBotBuilds

**Modded APKs & Magisk Modules — Instagram, YouTube, Music**

[![CI](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml)
[![Build](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/build.yml/badge.svg)](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/Chrispsz/rvcbotbuilds?include_prereleases&label=Latest%20Release)](https://github.com/Chrispsz/rvcbotbuilds/releases)
[![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?style=flat&logo=telegram&logoColor=white)](https://t.me/rvc_magisk)

Fork do [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module) com patches curados de múltiplas fontes.

</div>

---

## ✨ Features

- 📸 **Instagram** — 21 patches piko + 2 custom RVCBotBuilds (FLAG_SECURE + Quality Override)
- 🎬 **YouTube** — Morphe patches com tema AMOLED (preto puro)
- 🎵 **Music** — Morphe patches com tema AMOLED
- 🖤 **AMOLED** — Tema preto puro para YouTube e Music (`@android:color/black`)
- 📥 **Download** — Posts, reels, stories, highlights, profile pics, voice messages
- 🚫 **Ads** — Ads e conteúdo sugerido removidos
- 📸 **Screenshots em DMs** — FLAG_SECURE removido (custom patch)
- 🔍 **Qualidade** — Imagens 2048px + MobileConfig quality override
- 🔄 **CI Automático** — Checa atualizações de patches diariamente (13h BRT)
- 🛡️ **Auto-Detach** — Zygisk detach bloqueia atualizações da Play Store

---

## 📱 Apps

| App | Patches | Source | Base | Modo | Arch |
|-----|---------|--------|------|------|------|
| 📸 Instagram | 21 + 2 custom | crimera/piko v3.5.0-dev.2 | 430.0.0.53.80 | APK | arm64-v8a |
| 🎬 YouTube | Theme (AMOLED) | MorpheApp/morphe-patches | Auto | APK + Module | arm64-v8a |
| 🎵 Music | Theme (AMOLED) | MorpheApp/morphe-patches | Auto | APK + Module | arm64-v8a |

---

## 📸 Instagram Patches

### ✅ Included (21 piko + 2 custom = 23 total)

<details>
<summary><b>🖤 Theme & Visual</b></summary>

| Patch | Descrição |
|-------|-----------|
| Amoled theme | Tema preto puro para OLED |
| Hide stories tray | Remove barra de stories |
| Remove build expired popup | Remove popup de expiração |

</details>

<details>
<summary><b>🛡️ Privacidade</b></summary>

| Patch | Descrição |
|-------|-----------|
| Disable analytics | Bloqueia coleta de dados |
| Disable screenshot detection | Bypass alertas de screenshot |
| Disable typing status | Esconde indicador "digitando..." |
| Sanitize share links | Remove tracking de links compartilhados |

</details>

<details>
<summary><b>📥 Download</b></summary>

| Patch | Descrição |
|-------|-----------|
| Download media | Posts, reels, stories, highlights, profile pics, áudio |
| Download voice message | Salva mensagens de voz |

</details>

<details>
<summary><b>🚫 Ads & Feed</b></summary>

| Patch | Descrição |
|-------|-----------|
| Disable ads | Remove todos os anúncios |
| Hide suggested content | Remove posts sugeridos |

</details>

<details>
<summary><b>🔍 Qualidade & Mídia</b></summary>

| Patch | Descrição |
|-------|-----------|
| Improve image viewing | Imagens 2048px do CDN (vs 1080px default) |
| Make ephemeral media permanent | Mensagens "ver uma vez" ficam permanentes |
| View story mentions | Revela @menções ocultas em stories |

</details>

<details>
<summary><b>👤 Perfil & UX</b></summary>

| Patch | Descrição |
|-------|-----------|
| Copy comment | Copiar texto de qualquer comentário |
| Follow back indicator | Veja quem te segue de volta |
| More options on post | Ações extras ao segurar post |
| More options on profile | Ações extras no perfil |
| Open links externally | Abre links fora do app |

</details>

<details>
<summary><b>🔧 Configurações</b></summary>

| Patch | Descrição |
|-------|-----------|
| Add settings | Hub Piko Settings |
| Unlock developer options | Painel MetaConfig (segure ícone home) |

</details>

### 🔧 Custom RVCBotBuilds Patches (binary patches)

| Patch | Método | Efeito |
|-------|--------|--------|
| 📸 **Allow Screenshots in DMs** | FLAG_SECURE removal (binary dex patch) | Screenshot liberado em DMs — 531 ocorrências em 17 DEX files |
| 🔍 **MobileConfig Quality Override** | medium→high, standard→hd (binary string patch) | Qualidade de mídia maximizada — 338 substituições em 15 DEX files |

### ❌ Excluded (risky/detectable)

| Patch | Motivo |
|-------|--------|
| View DMs anonymously | Ghost mode — risco de ban |
| View live anonymously | Mesmo risco de detecção |
| View stories anonymously | Meta monitora — alto risco |
| Unlock employee options | Ferramentas internas da Meta |
| Unlock Plus benefits | Violação de TOS |
| Limit feed to following profiles | Quebra algoritmo do feed |
| Hide navigation buttons | Pode quebrar UI |

---

## 📥 Downloads

Baixe os APKs e módulos na página de [**Releases**](https://github.com/Chrispsz/rvcbotbuilds/releases).

| App | Formato | Root? | Requisito Extra |
|-----|---------|-------|-----------------|
| Instagram | APK | ❌ Não | Nenhum |
| YouTube | APK | ❌ Não | [GmsCore](https://github.com/ReVanced/GmsCore/releases) |
| YouTube | Module | ✅ Sim | Magisk/KernelSU |
| Music | APK | ❌ Não | [GmsCore](https://github.com/ReVanced/GmsCore/releases) |
| Music | Module | ✅ Sim | Magisk/KernelSU |

---

## ⚙️ Workflows

| Workflow | Trigger | Descrição |
|----------|---------|-----------|
| [`build.yml`](.github/workflows/build.yml) | Manual / Push | Build todos ou app específico |
| [`release-instagram.yml`](.github/workflows/release-instagram.yml) | Manual | Build Instagram + GitHub Release |
| [`ci.yml`](.github/workflows/ci.yml) | Diário 13h BRT | Auto-detect updates |

### Build Targets

| Target | Apps | Tempo aprox. |
|--------|------|-------------|
| `all` | Instagram + YouTube + Music | ~15 min |
| `instagram` | Instagram only | ~5 min |
| `youtube` | YouTube only | ~8 min |
| `music` | Music only | ~5 min |

---

## 🔨 Build Local

### Linux

```bash
git clone https://github.com/Chrispsz/rvcbotbuilds --depth 1
cd rvcbotbuilds
./build.sh
```

### Termux

```bash
bash <(curl -sSf https://raw.githubusercontent.com/Chrispsz/rvcbotbuilds/main/build-termux.sh)
```

> **Nota:** Keystores não estão no repo por segurança. São restaurados dos GitHub Secrets durante CI. Para build local, forneça seus próprios keystores.

---

## 📋 Config

Veja [`CONFIG.md`](./CONFIG.md) para referência completa de configuração.

---

## 🙏 Credits

| Projeto | O que faz |
|---------|----------|
| [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module) | Build system base |
| [crimera/piko](https://github.com/crimera/piko) | 46 Instagram patches |
| [MorpheApp/morphe-patches](https://github.com/MorpheApp/morphe-patches) | YouTube/Music patches + AMOLED |
| [j-hc/zygisk-detach](https://github.com/j-hc/zygisk-detach) | Auto-detach da Play Store |

---

<div align="center">

**[rvcbotbuilds](https://github.com/Chrispsz/rvcbotbuilds)** — feito com 🖤

</div>
