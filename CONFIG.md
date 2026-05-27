# Config

Adding another revanced app is as easy as this:
```toml
[Some-App]
apkmirror-dlurl = "https://www.apkmirror.com/apk/inc/app"
# or uptodown-dlurl = "https://app.en.uptodown.com/android"
```

> [!WARNING]
> When a patch name itself contains a single quote, double it inside the string (e.g. 'Hide ''Get Music Premium''').

## More about other options:

There exists an example below with all defaults shown and all the keys explicitly set.  
**All keys are optional** (except download urls) and are assigned to their default values if not set explicitly.  

```toml
parallel-jobs = 1                    # amount of cores to use for parallel patching, if not set $(nproc) is used
compression-level = 9                # module zip compression level
remove-rv-integrations-checks = true # remove checks from the revanced integrations
dpi = "nodpi anydpi 120-640dpi"      # dpi packages to be searched in order. default: "nodpi anydpi"

patches-source = "revanced/revanced-patches" # where to fetch patches bundle from. default: "revanced/revanced-patches"
cli-source = "ReVanced/revanced-cli"             # where to fetch cli from. default: "ReVanced/revanced-cli"
# options like cli-source can also set per app
rv-brand = "ReVanced Extended" # rebrand from 'ReVanced' to something different. default: "ReVanced"

patches-version = "v2.160.0" # 'latest', 'dev', or a version number. default: "latest"
cli-version = "v5.0.0"       # 'latest', 'dev', or a version number. default: "latest"

[Some-App]
app-name = "SomeApp" # if set, release name becomes SomeApp instead of Some-App. default is same as table name, which is 'Some-App' here.
enabled = true       # whether to build the app. default: true
build-mode = "apk"   # 'both', 'apk' or 'module'. default: apk

# 'auto' option gets the latest possible version supported by all the included patches
# 'latest' gets the latest stable without checking patches support. 'beta' gets the latest beta/alpha
# whitespace seperated list of patches to exclude. default: ""
version = "auto"     # 'auto', 'latest', 'beta' or a version number (e.g. '17.40.41'). default: auto

# optional args to be passed to cli. can be used to set patch options
# multiline strings in the config is supported
patcher-args = """\
  -OdarkThemeBackgroundColor=#FF0F0F0F \
  -Oanother-option=value \
  """

excluded-patches = """\
  'Some Patch' \
  'Some Other Patch' \
  """

included-patches = "'Some Patch'"                          # whitespace seperated list of non-default patches to include. default: ""
include-stock = "merged"                                   # 'merged', 'split' or 'disable'. default: merged
exclusive-patches = false                                  # exclude all patches by default. default: false

apkmirror-dlurl = "https://www.apkmirror.com/apk/inc/app"
uptodown-dlurl = "https://spotify.en.uptodown.com/android"
# direct download url. the url must have point to an apk file with name format shown in this example
direct-dlurl = "https://website/com.google.android.youtube-20.40.45-all.apk"

module-prop-name = "some-app-module"                       # module prop name.
dpi = "360-480dpi"                                         # used to select apk variant from apkmirror. default: nodpi
arch = "arm64-v8a"                                         # 'arm64-v8a', 'arm-v7a', 'all', 'both'. 'both' downloads both arm64-v8a and arm-v7a. default: all
```

## RVCBotBuilds Extra Options

These options are specific to this fork and are not available in the upstream j-hc repo:

```toml
# Global options
default-arch = "arm64-v8a"      # default architecture for all apps. default: "arm64-v8a"
continue-on-error = true        # continue building other apps if one fails. default: true

# RevPack (Combined Module) — optional
combine-modules = false         # bundle all built modules into one flashable zip. default: false
pack-name = "rvcbot-revpack"    # output filename for RevPack (without .zip). default: "rvcbot-revpack"
pack-apps = ""                  # comma-separated whitelist of apps to include in RevPack. default: "" (all)
pack-exclude-apps = ""          # comma-separated blacklist of apps to exclude from RevPack. default: "" (none)
```

### AMOLED Theme (YouTube & Music)

Both YouTube and Music use Morphe's Theme patch with pure black background (`@android:color/black`)
for true AMOLED dark mode — saves battery on OLED screens.

```toml
[YouTube-Morphe]
included-patches = "'Theme'"
patcher-args = "-OdarkThemeBackgroundColor=@android:color/black"

[Music-Morphe]
included-patches = "'Theme'"
patcher-args = "-OdarkThemeBackgroundColor=@android:color/black"
```

### Instagram with crimera/piko (46 patches)

Instagram uses `crimera/piko` which provides 46 Instagram patches — the most comprehensive source available.
Researched 7+ repos (piko, brosssh, InstaEclipse, Instafel, ReVanced, anddea, RookieEnough) — **piko wins by far**.

**Pre-configured patches (30 included in config.toml):**

| Category | Patches | Why |
|----------|---------|-----|
| 🖤 **Theme** | Amoled theme | Pure black for OLED |
| 👻 **Ghost Mode** | View stories/DMs/live anonymously | See without being seen |
| 🛡️ **Privacy** | Disable analytics, Disable screenshot detection, Disable typing status | Block Meta tracking |
| 📥 **Download** | Download media | Save posts, reels, stories, highlights, profile pics, audio |
| 🔍 **Image Quality** | Improve image viewing | **2048px from CDN** (vs 1080px default) |
| 🔧 **Dev Options** | Unlock developer options | Access MetaConfig flags (quality, experimental UI, etc.) |
| 🧹 **Clean Feed** | Hide navigation buttons, Hide suggested content, Hide notes tray, Hide reshare button, Disable Reels scrolling, Disable video autoplay, Remove empty bottom space | Distraction-free |
| 🔗 **Links** | Sanitize share links, Open links externally | Remove tracking, use real browser |
| 👤 **Profile** | Follow back indicator, More options on profile, More options on post, Copy comment | Better UX |
| 🔒 **Media** | Make ephemeral media permanent, View story mentions | Keep view-once media, see hidden mentions |
| ⏰ **Stories** | Customise story timestamp, Stories audio autoplay, Disable discover people, Disable double tap like, Remove build expired popup | Fine-tuned experience |

**Excluded patches (risky/unstable):**
- Unlock employee options (debugging, may crash)
- Unlock Plus benefits (server-side, risky)

**About "Improve image viewing":** Forces Instagram to request **2048px images** from the CDN instead of the default 1080px. This is NOT upscaling — Instagram stores originals at up to 2048px, but the app normally requests lower-res versions. The patch intercepts `ExtendedImageUrl` and `SetDPIMetrics` to request the max resolution. Toggle on in Piko Settings after install.

**About "Unlock developer options":** Long-press the home icon to access Instagram's internal developer panel (MetaConfig). This gives access to **hundreds of feature flags** including image quality caps, video encoding, experimental UI, and more. Think of it as a meta-patch that unlocks further customization.

**About "Download media":** Supports downloading feed posts, reels, stories, highlights, profile pictures, DM media, and audio tracks from reels. Has a download dialog with options: download current, download as image, download audio, copy link, open externally, download all (carousel). Configure in Piko Settings.

### Research: Other Instagram Mod Sources

| Repo | IG Patches | AMOLED | Privacy | Download | Image Quality | Dev Options |
|------|-----------|--------|---------|----------|---------------|-------------|
| **crimera/piko** 🏆 | **46** | ✅ | ✅ anon+analytics | ✅ full | ✅ 2048px | ✅ |
| brosssh/morphe-patches | 17 | ❌ | ❌ | ❌ | ❌ | ❌ |
| InstaEclipse (LSPosed) | N/A (Xposed) | ❌ | ✅ ghost mode | ✅ | ❌ | ✅ |
| Instafel (custom patcher) | 12 | ✅ (from piko) | ❌ | ❌ | ❌ | ✅ |
| ReVanced official | ~2 | ❌ | ❌ | ❌ | ❌ | ❌ |

**InstaEclipse** (LSPosed module) has unique features not in piko:
- **Allow Screenshots in DMs** — strips `FLAG_SECURE` from windows (no piko equivalent)
- **DM Mark-as-Read Button** — temporarily disables ghost mode to mark as read (no piko equivalent)
- **MobileConfig overrides** — bulk override ~100 server-side config flags for image quality
- However: requires root + LSPosed, project is discontinued (merging into Purrfect)

**Instafel** (custom Smali patcher) has unique features:
- **Unlock Dev Options** with cascading reference search (version-resilient)
- **Feature Flag Browser** via injected app UI
- However: no downloads, no ghost mode, no image quality — focuses on Alpha testing

**Feasibility of creating new Morphe patches from these:**
- 🟢 **Allow Screenshots in DMs** — Easy Smali patch, just mask out FLAG_SECURE flag
- 🟢 **MobileConfig Override Injection** — Override `mc_overrides.json` loading to merge custom quality flags
- 🟡 **Disable Feed entirely** — Medium, needs calling-code modification
- 🔴 **DM Mark-as-Read Button** — Requires runtime UI injection, not practical in Smali

### All 46 piko Instagram patches

Add settings, Allow user network certificate, **Amoled theme**, **Change like animation** (26 animations!),
Change version code, **Copy comment**, **Customise story ring size** (float, default 70.0f), **Customise story timestamp** (default/detailed/timeleft),
**Disable Reels scrolling**, **Disable ads**, **Disable analytics**, **Disable comments**,
**Disable discover people**, **Disable double tap like**, **Disable explore**, Disable highlights,
**Disable screenshot detection**, Disable stories, Disable story flipping, **Disable typing status**,
**Disable video autoplay**, **Download media** (posts+reels+stories+highlights+profile+DM+audio), **Follow back indicator**,
Hide group creation button on sharesheet, **Hide navigation buttons**, **Hide notes tray**,
**Hide reshare button**, Hide stories tray, **Hide suggested content**, **Improve image viewing** (2048px),
**Limit feed to following profiles**, **Make ephemeral media permanent**, **More options on post** (long-press: copy desc, download, etc),
**More options on profile** (copy handle, download DP, etc), **Open links externally**, **Remove build expired popup**,
**Remove empty bottom space**, **Sanitize share links**, **Stories audio autoplay**,
Unlock Plus benefits, **Unlock developer options** (long-press home → MetaConfig), Unlock employee options,
**View DMs anonymously**, **View live anonymously**, **View stories anonymously**, **View story mentions** (reveals hidden @tags)

**Bold** = included in our config.toml. Patches not bolded are available but excluded or not needed.

### RevPack

When `combine-modules = true`, all built Magisk modules are bundled into a single flashable zip.
This lets you install multiple root apps in one flash.

The RevPack includes auto-detach for all bundled apps and a per-app install prompt (Vol+/Vol- to choose).
