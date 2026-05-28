# Immutable Patch Overlay System

This directory contains **custom patches** that are automatically reapplied on top of upstream changes.

## How It Works

When the CI syncs with upstream `crimera/piko`, our custom modifications in this overlay
are **guaranteed to be reapplied** — even if the upstream repo changes the same files.

## Structure

```
overlay/
├── piko-patches/                    # Overlay for Chrispsz/piko fork
│   ├── HookFlags.java              # 257 preset flags + JSON override loading
│   ├── OtaUpdater.java             # In-app OTA updater (GitHub releases)
│   ├── DefaultStrings.java         # English: Piko → Mod rebrand
│   ├── StringsPortugueseBR.java    # PT-BR: Mod rebrand + OTA strings
│   ├── StringsKorean.java          # Korean: Mod rebrand
│   ├── StringsJapanese.java        # Japanese: Mod rebrand
│   ├── StringsHindi.java           # Hindi: Mod rebrand
│   ├── StringsIndonesian.java      # Indonesian: Mod rebrand
│   ├── StringsPolish.java          # Polish: Mod rebrand
│   ├── StringsRussian.java         # Russian: Mod rebrand
│   ├── StringsTurkish.java         # Turkish: Mod rebrand
│   ├── ScreenBuilder.java          # OTA settings section in UI
│   ├── SettingsActivity.java       # OTA section registration
│   └── Strings.java                # DEFAULT_PIKO_FOLDER → Mod-Instagram
├── apply-overlay.sh                 # Script that applies overlay to piko fork
└── README.md                        # This file
```

## Priority Chain

1. **Overlay files** (this directory) — ALWAYS win, applied last
2. **Upstream changes** — pulled from crimera/piko
3. **Fork base** — Chrispsz/piko (which includes overlay already applied)

## Adding New Custom Files

1. Add the file to `overlay/piko-patches/` with the **relative path** matching
   the piko repo structure (e.g. `extensions/instagram/src/main/java/...`)
2. Update `apply-overlay.sh` to copy the file
3. The CI workflow will automatically apply it on every sync

## Files NOT in overlay (handled by piko fork itself)

- `HookFlagsPatch.kt` — Kotlin patch that calls `HookFlags.presetFlags()`
- `PresetFlagsPatch.kt` — Kotlin patch registration
- `PikoSettingsButton.java` — Java class (method names unchanged)
- `Settings.java` — Internal prefs keys (unchanged for compatibility)
