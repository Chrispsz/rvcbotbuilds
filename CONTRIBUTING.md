# Contributing to RVCArise

Thanks for your interest in improving RVCArise! This fork of
[`j-hc/revanced-magisk-module`](https://github.com/j-hc/revanced-magisk-module)
adds curated patches (AMOLED theme, ad-free, downloads, etc.) and an automated
CI pipeline that rebuilds only when something actually changes.

## Repository layout

```
.
├── .github/workflows/ci.yml     # CI pipeline (preflight → sync → build → release)
├── build-meta/                  # Tracking files (what we last built)
│   ├── jhc-upstream-sha.txt     #   last j-hc commit we synced
│   ├── morphe-version.txt       #   last Morphe patches version
│   └── zygisk-detach-version.txt#   last zygisk-detach version
├── bin/                         # Prebuilt tools (LFS-tracked): aapt2, apksigner, toml, htmlq
├── ksu_profile/                 # KernelSU profile C source (prebuilt in module/bin/)
├── module/                      # Magisk module template
│   ├── customize.sh             #   install-time script (mount APK, setup detach)
│   ├── service.sh               #   boot-time script (re-mount APK)
│   ├── post-fs-data.sh          #   early boot (denylist cleanup)
│   ├── uninstall.sh             #   cleanup on uninstall
│   ├── bin/{arm,arm64,x86,x64}/ #   per-arch binaries (detach, ksu_profile) — LFS
│   └── zygisk/                  #   zygisk .so files — LFS
├── scripts/utilities/           # CI + build helpers
│   ├── gh-api.sh                #   GitHub API wrapper with retry/backoff
│   ├── ci-helpers.sh            #   logging, file validation, backup/restore
│   ├── update-zygisk-detach.sh  #   pull latest zygisk-detach release
│   ├── combine-modules.sh       #   bundle all apps into one RevPack zip
│   └── notify.sh                #   Telegram notification on CI result
├── build.sh                     # main build entrypoint (reads config.toml)
├── build-termux.sh              # on-device build (Termux)
├── config.toml                  # patch selection (THE file to edit)
├── utils.sh                     # shared build utilities
├── generate-changelog.py        # release notes generator
├── README.md                    # user-facing docs
└── CONFIG.md                    # config.toml reference
```

## How the CI pipeline works

The workflow in `.github/workflows/ci.yml` has 7 jobs:

| Job | When it runs | What it does |
|-----|--------------|--------------|
| `preflight` | always (daily 13:00 BRT) | update zygisk-detach, check j-hc/Morphe versions, decide if build is needed |
| `sync-upstream` | only if j-hc changed AND build-affecting files differ | merge j-hc preserving our customizations |
| `build` | only if `SHOULD_BUILD=1` and sync didn't fail | patch APKs, build modules, validate sizes |
| `release` | only if build succeeded | create GitHub release with all artifacts |
| `update-meta` | only if release succeeded | record versions in `build-meta/` so next run can skip |
| `cleanup` | after release or on skip | delete releases >7 days old, keep 3 workflow runs |
| `notify` | always (last) | send Telegram message if any job failed |

### Skip logic (why we don't rebuild every day)

The `preflight` job uses 4 layers of deduplication:

1. **j-hc SHA** — compare upstream `main` SHA with `build-meta/jhc-upstream-sha.txt`
2. **Build-affecting diff** — even if j-hc changed, skip if only README/.github/docs changed
3. **Morphe version** — compare latest stable tag with `build-meta/morphe-version.txt`
4. **Already released** — if the latest release body already mentions the current Morphe version, skip

Only if one of these layers says "yes, something changed" does `SHOULD_BUILD=1`.

## Forking & setting up your own

1. Fork the repo.
2. Add these **repository secrets** (Settings → Secrets and variables → Actions):
   - `PAT_TOKEN` — a classic PAT with `repo` + `workflow` scopes (so pushes trigger CI)
   - `KS_KEYSTORE_B64` — base64 of your keystore (`base64 ks.keystore`)
   - `KS_P12_KEYSTORE_B64` — base64 of your p12 keystore
   - `KS_PASSWORD` — keystore password
   - `TELEGRAM_BOT_TOKEN` — (optional) bot token from @BotFather
   - `TELEGRAM_CHAT_ID` — (optional) chat ID from @userinfobot
3. Enable Git LFS (it's free for the first 1 GB).
4. Edit `config.toml` to pick your patches.
5. Trigger the workflow manually (Actions → CI Build and Release → Run workflow).

## Editing patches

All patch selection lives in `config.toml`. See `CONFIG.md` for the full reference.

When adding/removing a patch:
- Quote patch names: `'Hide ads'` not `Hide ads`
- Test locally with `./build.sh` before pushing
- Document why a patch is excluded (reference the issue number if it's buggy)

## CI file protection

The `sync-upstream` job preserves these files when merging from j-hc:

```
config.toml, .github/workflows/ci.yml, build-meta/,
scripts/utilities/*.sh, module/{post-fs-data,service,uninstall,customize}.sh,
generate-changelog.py, README.md, CONFIG.md, CONTRIBUTING.md
```

If you add a new custom file that j-hc also has, add it to `PROTECTED_FILES` in
`.github/workflows/ci.yml` or it will be overwritten on the next sync.

## Reporting bugs

Open an issue with:
- What you expected
- What happened
- The release tag or commit SHA
- Your device (arch, root method: Magisk/KernelSU)
- Logcat or Magisk install log if relevant
