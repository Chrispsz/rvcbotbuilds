# Immutable Patch Overlay System

This directory contains **custom patches** that are automatically reapplied on top of upstream changes.

## How It Works

When the CI syncs with upstream `crimera/piko`, our custom modifications in this overlay
are **guaranteed to be reapplied** — even if the upstream repo changes the same files.

## Structure

```
overlay/
├── piko-patches/                    # Overlay for Chrispsz/piko fork
│   ├── HookFlags.java              # 76 preset MetaConfig flags + JSON override loading
│   ├── InstagramButton.java        # Reflection-safe setText (IgdsButton compat v430+)
│   ├── OtaUpdater.java             # Smart OTA v3 (build numbers, signature check, i18n)
│   ├── WelcomeMessage.java         # Silent first-time + auto OTA check
│   ├── ScreenBuilder.java          # OTA section with version info
│   ├── SettingsActivity.java       # OTA section registration
│   ├── Strings.java                # Constants + formatTagDisplay utility
│   ├── translations/
│   │   ├── DefaultStrings.java     # English: Mod rebrand + OTA strings
│   │   ├── StringsPortugueseBR.java # PT-BR: Mod rebrand + OTA + runtime strings
│   │   ├── StringsKorean.java      # Korean: Mod rebrand
│   │   ├── StringsJapanese.java    # Japanese: Mod rebrand
│   │   ├── StringsHindi.java       # Hindi: Mod rebrand
│   │   ├── StringsIndonesian.java  # Indonesian: Mod rebrand
│   │   ├── StringsPolish.java      # Polish: Mod rebrand
│   │   ├── StringsRussian.java     # Russian: Mod rebrand
│   │   └── StringsTurkish.java     # Turkish: Mod rebrand
├── apply-overlay.sh                 # Script that applies overlay to piko fork
└── README.md                        # This file
```

## Priority Chain

1. **JSON override** (`mc_overrides.json`) — highest priority, no-root editable
2. **Hardcoded flags** (HookFlags.java BOOL_FLAGS) — preset quality/privacy/ads flags
3. **Overlay files** (this directory) — ALWAYS win over upstream, applied last
4. **Upstream changes** — pulled from crimera/piko
5. **Fork base** — Chrispsz/piko (which includes overlay already applied)

## Adding New Custom Files

1. Add the file to `overlay/piko-patches/` with the **relative path** matching
   the piko repo structure (e.g. `extensions/instagram/src/main/java/...`)
2. Update `apply-overlay.sh` to copy the file
3. The CI workflow will automatically apply it on every sync
