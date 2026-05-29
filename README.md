<div align="center">

# 📸🎬🎵 RVCArise

**Modded APKs & Magisk Modules — Instagram, YouTube, Music**

[![CI](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Chrispsz/rvcbotbuilds?include_prereleases&label=Latest%20Release)](https://github.com/Chrispsz/rvcbotbuilds/releases)

Fork do [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module) com patches curados de múltiplas fontes.

</div>

---

## ✨ Features

- 📸 **Instagram** — 21 patches piko + 76 MetaConfig flags + OTA updater
- 🎬 **YouTube** — Morphe patches com tema AMOLED (preto puro)
- 🎵 **Music** — Morphe patches com tema AMOLED
- 🖤 **AMOLED** — Tema preto puro para YouTube e Music (`@android:color/black`)
- 📥 **Download** — Posts, reels, stories, highlights, profile pics, voice messages
- 🚫 **Ads** — Ads e conteúdo sugerido removidos
- 🔍 **Qualidade** — Imagens 2048px + 76 MetaConfig quality/privacy/download flags
- 🔄 **OTA** — Atualização automática do mod direto no app (24h cooldown, build numbers)
- 🔄 **CI Inteligente** — Checa atualizações de patches diariamente (13h BRT), só rebuilda o que mudou

---

## 📱 Apps

| App | Patches | Source | Base | Modo | Arch |
|-----|---------|--------|------|------|------|
| 📸 Instagram | 21 + 76 flags + OTA | Chrispsz/piko (fork) | 430.0.0.53.80 | APK | arm64-v8a |
| 🎬 YouTube | Theme (AMOLED) | MorpheApp/morphe-patches | Auto | APK + Module | arm64-v8a |
| 🎵 Music | Theme (AMOLED) | MorpheApp/morphe-patches | Auto | APK + Module | arm64-v8a |

---

## 📸 Instagram Patches

### ✅ Included (21 piko patches)

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
| Add settings | Hub Mod Settings com OTA + reload config |
| Unlock developer options | Painel MetaConfig (segure ícone home) |

</details>

### 🔧 MetaConfig Flags (76 hardcoded + JSON override)

| Categoria | Count | Efeito |
|-----------|-------|--------|
| Stories crash fix | 3 | Previne crash no v430+ |
| Image/video quality | 13 | Upload, streaming, cache em resolução máxima |
| Download media | 7 | Download direto, stories, reels, highlights |
| Ads & sponsored | 11 | Remove ads do feed, explore, reels, search |
| Analytics & tracking | 11 | Bloqueia logging, heartbeat, fingerprint |
| Privacy | 12 | Screenshot, typing, read receipts, tracking |
| Build/OTA | 2 | Remove expirado, skip update check |
| Links/sharing | 4 | Sanitize, open externally, block tracking |
| UI | 1 | Remove empty bottom space |
| Contact consent | 4 | Permissão de contato |
| Overflow menu | 4 | Menu overflow simplificado |

> **Priority:** JSON override (`/sdcard/Android/media/com.instagram.android/mc_overrides.json`) > hardcoded flags

### ❌ Excluded (risky/detectable)

| Patch | Motivo |
|-------|--------|
| View DMs anonymously | Ghost mode — risco de ban |
| View live anonymously | Mesmo risco de detecção |
| View stories anonymously | Meta monitora — alto risco |
| Unlock employee options | Ferramentas internas da Meta |
| Unlock Plus benefits | Violação de TOS |

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
| [`ci.yml`](.github/workflows/ci.yml) | Diário 13h BRT + Manual | Smart CI — só rebuilda o que mudou |
| [`build-instagram.yml`](.github/workflows/build-instagram.yml) | Chamado pelo CI | Build Instagram APK |
| [`build-youtube.yml`](.github/workflows/build-youtube.yml) | Chamado pelo CI | Build YouTube + Music |

### Smart CI

- Verifica se patches ou base APK mudaram
- Só rebuilda apps com mudanças upstream
- Assets de apps inalterados são carried forward
- Mesmo-dia builds recebem build number incremental (`v2025.05.29-1`, `v2025.05.29-2`)
- Releases antigos do mesmo dia são marcados como prerelease
- Releases com mais de 7 dias são auto-deletados

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
| [crimera/piko](https://github.com/crimera/piko) | 46 Instagram patches (upstream) |
| [Chrispsz/piko](https://github.com/Chrispsz/piko) | Piko fork com overlay custom |
| [MorpheApp/morphe-patches](https://github.com/MorpheApp/morphe-patches) | YouTube/Music patches + AMOLED |
| [j-hc/zygisk-detach](https://github.com/j-hc/zygisk-detach) | Auto-detach da Play Store |

---

<div align="center">

**[RVCArise](https://github.com/Chrispsz/rvcbotbuilds)** — feito com 🖤

</div>
