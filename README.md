<div align="center">

# 📸🎬🎵 RVCArise

**Modded APKs & Magisk Modules — Instagram, YouTube, Music**

[![CI](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml/badge.svg?event=schedule)](https://github.com/Chrispsz/rvcbotbuilds/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Chrispsz/rvcbotbuilds?include_prereleases&label=Latest%20Release)](https://github.com/Chrispsz/rvcbotbuilds/releases)

Fork do [j-hc/revanced-magisk-module](https://github.com/j-hc/revanced-magisk-module) com patches oficiais.

</div>

---

## ✨ Features

- 📸 **Instagram** — 11 patches oficiais do crimera/piko
- 🎬 **YouTube** — Morphe patches com tema AMOLED (preto puro)
- 🎵 **Music** — Morphe patches com tema AMOLED
- 🖤 **AMOLED** — Tema preto puro para YouTube e Music (`@android:color/black`)
- 📥 **Download** — Posts, reels, stories, highlights, profile pics
- 🚫 **Ads** — Ads e conteúdo sugerido removidos
- 🔍 **Qualidade** — Imagens 2048px do CDN
- 🔄 **CI Inteligente** — Checa atualizações de patches diariamente (13h BRT), só rebuilda o que mudou

---

## 📱 Apps

| App | Patches | Source | Base | Modo | Arch |
|-----|---------|--------|------|------|------|
| 📸 Instagram | 11 oficiais | crimera/piko | 430.0.0.53.80 | APK | arm64-v8a |
| 🎬 YouTube | Theme (AMOLED) | MorpheApp/morphe-patches | Auto | APK + Module | arm64-v8a |
| 🎵 Music | Theme (AMOLED) | MorpheApp/morphe-patches | Auto | APK | arm64-v8a |

---

## 📸 Instagram Patches

### ✅ Included (11 official crimera/piko patches)

| Patch | Descrição |
|-------|-----------|
| Add settings | Hub Piko Settings no menu |
| Amoled theme | Tema preto puro para OLED |
| Disable analytics | Bloqueia coleta de dados |
| Disable ads | Remove todos os anúncios |
| Download media | Posts, reels, stories, highlights, profile pics |
| Hide suggested content | Remove posts sugeridos |
| Improve image viewing | Imagens 2048px do CDN |
| More options on post | Ações extras ao segurar post |
| Open links externally | Abre links fora do app |
| Remove build expired popup | Remove popup de expiração |
| Unlock developer options | Painel de developer options |

---

## 📥 Downloads

Baixe os APKs e módulos na página de [**Releases**](https://github.com/Chrispsz/rvcbotbuilds/releases).

| App | Formato | Root? | Requisito Extra |
|-----|---------|-------|-----------------|
| Instagram | APK | ❌ Não | Nenhum |
| YouTube | APK | ❌ Não | [GmsCore](https://github.com/ReVanced/GmsCore/releases) |
| YouTube | Module | ✅ Sim | Magisk/KernelSU |
| Music | APK | ❌ Não | [GmsCore](https://github.com/ReVanced/GmsCore/releases) |

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
- Mesmo-dia builds recebem build number incremental
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
| [crimera/piko](https://github.com/crimera/piko) | Instagram patches oficiais |
| [MorpheApp/morphe-patches](https://github.com/MorpheApp/morphe-patches) | YouTube/Music patches + AMOLED |
| [j-hc/zygisk-detach](https://github.com/j-hc/zygisk-detach) | Auto-detach da Play Store |

---

<div align="center">

**[RVCArise](https://github.com/Chrispsz/rvcbotbuilds)** — feito com 🖤

</div>
