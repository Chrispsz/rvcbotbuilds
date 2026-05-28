# RVCBotBuilds Config Guide

## Quick Start

1. ⭐ Star the repo
2. Fork or use as [template](https://github.com/Chrispsz/rvcbotbuilds/generate)
3. Customize [`config.toml`](./config.toml)
4. Run the [build workflow](../../actions/workflows/build.yml) or [Instagram release](../../actions/workflows/release-instagram.yml)
5. Download from [releases](../../releases)

---

## Apps

### 📸 Instagram (crimera/piko v3.5.0-dev.2)

Instagram uses `crimera/piko` with `exclusive-patches = true` — only explicitly included patches are applied. We include 21 of 46 available patches, plus 2 custom RVCBotBuilds binary patches.

**Included patches (21):**

| Category | Patches |
|----------|---------|
| 🖤 **Theme** | Amoled theme |
| 🛡️ **Privacy** | Disable analytics, Disable screenshot detection, Disable typing status |
| 📥 **Download** | Download media, Download voice message |
| 🚫 **Ads** | Disable ads, Hide suggested content |
| 🔍 **Quality** | Improve image viewing (2048px from CDN) |
| 👤 **Profile** | Copy comment, Follow back indicator, More options on post, More options on profile |
| 🔧 **Settings** | Add settings, Unlock developer options |
| 🔒 **Media** | Make ephemeral media permanent, View story mentions |
| 🔗 **Links** | Open links externally, Sanitize share links |
| 🧹 **Clean** | Hide stories tray, Remove build expired popup |

**Custom RVCBotBuilds patches (2 binary patches):**
- **Allow Screenshots in DMs** — removes `FLAG_SECURE` (0x2000) from Window.setFlags() calls via binary dex patching. Allows taking screenshots in DM conversations.
- **MobileConfig Quality Override** — replaces quality string constants in DEX string table: `medium` → `high`, `standard` → `hd`. Maximizes image/video quality from server-side config.

**Excluded patches (7 — risky/detectable):**
- `View DMs anonymously` — Ghost mode in DMs, Instagram can detect
- `View live anonymously` — Same detection risk
- `View stories anonymously` — High detection risk, Meta monitors
- `Unlock employee options` — Exposes internal Meta tools, can crash
- `Unlock Plus benefits` — TOS violation, detectable
- `Limit feed to following profiles` — Breaks feed algorithm
- `Hide navigation buttons` — Can break UI

### 🎬 YouTube (MorpheApp/morphe-patches)

YouTube uses Morphe patches with AMOLED dark theme (pure black `@android:color/black`).
- Build mode: both (APK + Magisk module)
- Auto-detach via Zygisk blocks Play Store updates
- Requires [GmsCore](https://github.com/ReVanced/GmsCore/releases) for non-root

### 🎵 Music (MorpheApp/morphe-patches)

Same as YouTube — Morphe patches with AMOLED theme.
- Build mode: both (APK + Magisk module)

---

## Config Reference

### Global Options

```toml
enable-module-update = true     # Enable Magisk module updates. default: true
parallel-jobs = 3               # Cores for parallel patching. default: $(nproc)
compression-level = 9           # Module zip compression (0-9). default: 9
riplib = true                   # Rip lib files for smaller modules. default: true
remove-rv-integrations-checks = true  # Remove revanced-integrations checks. default: true
continue-on-error = true        # Continue if one app fails. default: true
default-arch = "arm64-v8a"      # Default architecture for all apps. default: "arm64-v8a"
```

### Per-App Options

```toml
[App-Name]
app-name = "App"                  # Display name. default: table name
enabled = true                    # Build this app. default: true
patches-source = "org/repo"       # Patches GitHub repo. default: "ReVanced/revanced-patches"
patches-version = "latest"        # "latest", "dev", or version tag. default: "latest"
cli-source = "org/repo"           # CLI GitHub repo. default: "ReVanced/revanced-cli"
rv-brand = "Brand"                # Brand name for output. default: "ReVanced"
build-mode = "apk"                # "apk", "module", or "both". default: "apk"
version = "auto"                  # "auto", "latest", "beta", or version string. default: "auto"
exclusive-patches = false         # Only apply explicitly included patches. default: false
arch = "arm64-v8a"                # "arm64-v8a", "arm-v7a", "x86_64", "x86", "all", "both". default: "all"

included-patches = """\
  'Patch Name 1' \
  'Patch Name 2' \
  """

excluded-patches = """\
  'Patch Name 3' \
  """

patcher-args = "--continue-on-error"  # Extra args for the patcher CLI

# Download sources (at least one required, tried in order: direct → uptodown → archive → apkmirror)
uptodown-dlurl = "https://app.en.uptodown.com/android"
apkmirror-dlurl = "https://www.apkmirror.com/apk/dev/app"
direct-dlurl = "https://example.com/app-1.0.apk"
```

### Instagram-Specific Config

```toml
[Instagram-Piko]
app-name = "Instagram"
patches-source = "crimera/piko"
patches-version = "dev"            # Uses latest dev release from piko
cli-source = "MorpheApp/morphe-cli"
rv-brand = "Morphe"
build-mode = "apk"
version = "430.0.0.53.80"          # Pinned version (piko officially supported)
exclusive-patches = true            # Only explicitly included patches
patcher-args = "--continue-on-error"
arch = "arm64-v8a"
uptodown-dlurl = "https://instagram.en.uptodown.com/android"
```

> **Why `patches-version = "dev"`?** The dev channel includes fixes for newer Instagram versions before they're released as stable. We use v3.5.0-dev.2 which adds official support for v430.

> **Why `exclusive-patches = true`?** With 46 available patches, we want fine control over which ones apply. This prevents unexpected patches from being included.

> **Why pin `version = "430.0.0.53.80"`?** This is the version officially supported by piko v3.5.0-dev.2. Auto-detect may pick an unsupported version that breaks patches.

---

## Custom Patches

RVCBotBuilds applies custom binary patches AFTER the ReVanced CLI finishes patching. These are patches not available in crimera/piko but found in other mods (InstaEclipse, Instafel).

Binary dex patching is used by design — direct DEX byte manipulation requires no decompile/recompile step and works reliably on large APKs.

### How Binary Patching Works

1. Pre-flight check: verify APK exists and is readable
2. Extract DEX files from the patched APK
3. Use python3 to scan and modify bytes directly (no decompile needed)
4. Update the modified DEX files in the APK
5. Re-sign the APK (binary patches invalidate the signature)

**Advantages:** Fast (seconds per DEX), no decompile/recompile step, works on any APK size.

**Current binary patches:**
- `FLAG_SECURE removal`: Scans for `const/16 vN, 0x2000` opcodes (0x13 + register + LE 0x2000) and replaces with 0x0000. Applied to ALL DEX files.
- `Quality Override` *(context-gated)*: Scans for `medium` and `standard` byte strings and replaces with `high\x00\x00` and `hd\x00\x00\x00\x00\x00\x00`. **Only operates on DEX files that contain quality-related context strings** (`upload_quality`, `MobileConfig`, `image_quality`, `video_quality`, `quality_tier`) to avoid false-positive replacements in unrelated strings (e.g., `medium_font`, `standard_layout`).

See [`custom-patches/apply-custom-patches.sh`](./custom-patches/apply-custom-patches.sh) for implementation.

---

## Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `build.yml` | Manual / Push to main | Build all or specific apps |
| `release-instagram.yml` | Manual | Instagram-only build + GitHub Release |
| `ci.yml` | Daily 13:00 BRT / Manual | Auto-detect patch/base updates |

### Build Targets

When using `build.yml` or `ci.yml`, you can specify which app to build:

| Target | Apps Built | Approx. Time |
|--------|-----------|-------------|
| `all` | Instagram + YouTube + Music | ~15 min |
| `instagram` | Instagram only | ~5 min |
| `youtube` | YouTube only | ~8 min |
| `music` | Music only | ~5 min |

---

## Building Locally

### On Linux

```bash
git clone https://github.com/Chrispsz/rvcbotbuilds --depth 1
cd rvcbotbuilds
# Place keystores in the root directory
./build.sh
```

### On Termux

```bash
bash <(curl -sSf https://raw.githubusercontent.com/Chrispsz/rvcbotbuilds/main/build-termux.sh)
```

> **Note:** Keystores (`ks.keystore`, `ks-p12.keystore`) are NOT included in the repo for security. They are stored as GitHub Secrets and restored during CI builds. For local builds, you need your own keystores.

---

## Research: Instagram Patch Sources

| Repo | IG Patches | AMOLED | Privacy | Download | Image Quality | Dev Options |
|------|-----------|--------|---------|----------|---------------|-------------|
| **crimera/piko** 🏆 | **46** | ✅ | ✅ anon+analytics | ✅ full | ✅ 2048px | ✅ |
| brosssh/morphe-patches | 17 | ❌ | ❌ | ❌ | ❌ | ❌ |
| InstaEclipse (LSPosed) | N/A (Xposed) | ❌ | ✅ ghost mode | ✅ | ❌ | ✅ |
| Instafel (custom patcher) | 12 | ✅ (from piko) | ❌ | ❌ | ❌ | ✅ |
| ReVanced official | ~2 | ❌ | ❌ | ❌ | ❌ | ❌ |

**InstaEclipse** unique features (not in piko):
- Allow Screenshots in DMs → ✅ We implement this as a binary patch
- MobileConfig overrides → ✅ We implement this as a binary patch
- DM Mark-as-Read Button → ❌ Requires runtime UI injection
