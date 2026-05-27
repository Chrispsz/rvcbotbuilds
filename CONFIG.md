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

# RevPack (Combined Module)
combine-modules = true          # bundle all built modules into one flashable zip. default: false
pack-name = "rvcbot-revpack"    # output filename for RevPack (without .zip). default: "rvcbot-revpack"
pack-apps = ""                  # comma-separated whitelist of apps to include in RevPack. default: "" (all)
pack-exclude-apps = ""          # comma-separated blacklist of apps to exclude from RevPack. default: "" (none)
```

### Instagram with brosssh/morphe-patches

Instagram is supported via `brosssh/morphe-patches` which provides 17 patches:
- Hide ads, Hide Instants, Hide Reels save button, Hide Stories from Home
- Hide Threads profile button, Hide explore feed, Hide feed content
- Hide navigation buttons (6 options), Hide notes tray, Hide reshare button
- Hide suggested content, Limit feed to following profiles
- Disable Reels scrolling, Disable story auto flipping, Disable video autoplay
- Bypass signature check, Remove build expired popup

```toml
[Instagram-Morphe]
app-name = "Instagram"
patches-source = "brosssh/morphe-patches"
cli-source = "MorpheApp/morphe-cli"
rv-brand = "Morphe"
build-mode = "apk"
arch = "arm64-v8a"
excluded-patches = "'Unlock developer options'"
uptodown-dlurl = "https://instagram.en.uptodown.com/android"
```

### RevPack

When `combine-modules = true`, all built Magisk modules are bundled into a single flashable zip.
This lets you install YouTube + Music + any other module apps in one flash.

The RevPack includes auto-detach for all bundled apps and a per-app install prompt (Vol+/Vol- to choose).
