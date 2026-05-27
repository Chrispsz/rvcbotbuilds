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

**Pre-configured patches (included by default in config.toml):**

| Category | Patches | Why |
|----------|---------|-----|
| 🖤 **Theme** | Amoled theme | Pure black for OLED |
| 🛡️ **Privacy** | View stories anonymously, View DMs anonymously, View live anonymously | Ghost mode — see without being seen |
| 🛡️ **Privacy** | Disable analytics, Disable screenshot detection, Disable typing status | Block Meta tracking |
| 📥 **Download** | Download media | Save posts, reels, stories, highlights |
| 🧹 **Clean Feed** | Hide navigation buttons, Hide suggested content, Hide ads | Distraction-free |
| 🔗 **Links** | Sanitize share links, Open links externally | Remove tracking, use real browser |
| 👤 **Profile** | Follow back indicator, Improve image viewing | Better UX |
| 🔒 **Media** | Make ephemeral media permanent | Keep view-once media |

**Excluded patches (potentially risky/unstable):**
- Unlock developer options
- Unlock employee options
- Unlock Plus benefits

```toml
[Instagram-Piko]
app-name = "Instagram"
patches-source = "crimera/piko"
patches-version = "dev"
cli-source = "MorpheApp/morphe-cli"
rv-brand = "Morphe"
build-mode = "apk"
arch = "arm64-v8a"
included-patches = """\
  'Amoled theme' \
  'Download media' \
  'View stories anonymously' \
  'View DMs anonymously' \
  'View live anonymously' \
  'Disable analytics' \
  'Disable screenshot detection' \
  'Disable typing status' \
  'Sanitize share links' \
  'Open links externally' \
  'Follow back indicator' \
  'Improve image viewing' \
  'Make ephemeral media permanent' \
  'Hide navigation buttons' \
  """
excluded-patches = """\
  'Unlock developer options' \
  'Unlock employee options' \
  'Unlock Plus benefits' \
  """
uptodown-dlurl = "https://instagram.en.uptodown.com/android"
```

**All 46 piko Instagram patches available:**
Add settings, Allow user network certificate, Amoled theme, Change like animation,
Change version code, Copy comment, Customise story ring size, Customise story timestamp,
Disable Reels scrolling, Disable ads, Disable analytics, Disable comments,
Disable discover people, Disable double tap like, Disable explore, Disable highlights,
Disable screenshot detection, Disable stories, Disable story flipping, Disable typing status,
Disable video autoplay, Download media, Follow back indicator,
Hide group creation button on sharesheet, Hide navigation buttons, Hide notes tray,
Hide reshare button, Hide stories tray, Hide suggested content, Improve image viewing,
Limit feed to following profiles, Make ephemeral media permanent, More options on post,
More options on profile, Open links externally, Remove build expired popup,
Remove empty bottom space, Sanitize share links, Stories audio autoplay,
Unlock Plus benefits, Unlock developer options, Unlock employee options,
View DMs anonymously, View live anonymously, View stories anonymously, View story mentions

### RevPack

When `combine-modules = true`, all built Magisk modules are bundled into a single flashable zip.
This lets you install multiple root apps in one flash.

The RevPack includes auto-detach for all bundled apps and a per-app install prompt (Vol+/Vol- to choose).
