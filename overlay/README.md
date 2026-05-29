# Immutable Patch Overlay System

This directory contains **custom patches** that are automatically reapplied on top of upstream changes.

## How It Works

When the CI syncs with upstream `crimera/piko`, our custom modifications in this overlay
are **guaranteed to be reapplied** — even if the upstream repo changes the same files.

## Structure

```
overlay/
├── piko-patches/                    # Overlay for Chrispsz/piko fork
│   ├── Constants.kt                 # Instagram version compatibility (declares supported version)
│   ├── HookFlags.java              # Patch flags ONLY — no JSON loading
│   ├── InstagramButton.java        # Reflection-safe setText (IgdsButton compat v430+)
│   ├── OtaUpdater.java             # Smart OTA v3 (build numbers, signature check, i18n)
│   ├── WelcomeMessage.java         # Silent first-time + auto OTA check
│   ├── DebugReceiver.java          # ADB debug commands (always-on, no toggle needed)
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

## Flag Policy

**Only REAL Instagram MobileConfigSpecifier IDs are used in HookFlags.java.**
No JSON loading — only hardcoded patch flags for maximum stability.

### Why No JSON Loading?

1. **Stability** — fewer moving parts, no file I/O on the critical config check path
2. **Simplicity** — no JSON parsing, no file not found errors, no permission issues
3. **Instagram has its own importer** — users who need extra flags can use
   Mod Settings → Developer options → Import overrides
4. **Less attack surface** — no externally writable config file that could be tampered with

### How Boolean Flags Work

1. Piko's `HookFlagsPatch.kt` injects a smali hook into Instagram's boolean
   config check method (`MobileConfigSpecifier`)
2. `HookFlags.handleBoolFlags(long)` parses the config ID (e.g., `"110800::0"`)
3. If the ID is in our `BOOL_FLAGS` map, the override value is returned
4. If not found, Instagram's original logic runs normally

### Flag Categories in HookFlags.java

| Category | Method | Count | Source |
|----------|--------|-------|--------|
| Contact permission | `contactPermissionConsentFlags()` | 4 | piko source |
| Overflow menu | `simpleOverflowMenuFlags()` | 4 | piko source |
| Ads | `adsFlags()` | 6 | piko source + verified |
| Employee options | `employeeOptionsFlags()` | 1 | piko source |

### Adding Extra Flags (User-Side)

If users need more flags beyond what's hardcoded, they can:
1. Open Mod Settings → Developer options
2. Enable "Enable developer options"
3. Use "Import overrides" to load a JSON file
4. Instagram's built-in importer handles all param types (bool, int, string, float)

## Debug Tools

### ADB Debug (Primary — No Toggle Needed)

Our `DebugReceiver` is always registered on app launch. No need to enable
anything in the app — just connect ADB:

```bash
# View mod logs
adb logcat -s ModDebug

# Available commands
adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command status
adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command dump_flags
adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command toggle_debug
adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command export_log
adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command version
```

### Piko Debug Toggle (Optional In-App)

The "Mod debug" toggle in settings enables piko's built-in debug features:
- Export experiment list
- Export experiment mappings
- In-app flag dump and diagnostics

This is optional — ADB debug works independently.

## Priority Chain

1. **Hardcoded boolean flags** (HookFlags.java BOOL_FLAGS) — verified real flags, always active
2. **Instagram's built-in importer** — user-imported overrides via developer options
3. **Overlay files** (this directory) — ALWAYS win over upstream, applied last
4. **Upstream changes** — pulled from crimera/piko
5. **Fork base** — Chrispsz/piko (which includes overlay already applied)

## ⚠️ CRITICAL: Overlay Must Be Compiled Into .mpp

The overlay modifies **source code**, not the pre-built `.mpp` file.
For the overlay to take effect, the CI must:

1. Clone `Chrispsz/piko` fork
2. Run `apply-overlay.sh` to apply custom files
3. **Build the .mpp from source** using Gradle
4. Use the custom-built .mpp (not download from releases)

If the build process downloads a pre-built .mpp from GitHub releases,
the overlay has **NO EFFECT** — the custom HookFlags, OtaUpdater, etc.
won't be in the final APK.

## Version Compatibility

The `Constants.kt` overlay declares which Instagram version the patches support.
With `config.toml` set to `version = "auto"`, the CLI will automatically
pick the Instagram version supported by the .mpp, preventing the silent
"all patches skipped" bug.

## Adding New Custom Files

1. Add the file to `overlay/piko-patches/` with the **relative path** matching
   the piko repo structure (e.g. `extensions/instagram/src/main/java/...`)
2. Update `apply-overlay.sh` to copy the file
3. The CI workflow will automatically apply it on every sync

## Build Diagnostics

Run `./diagnose-build.sh` after a build to check:
- Whether patches were applied (DEX class check)
- Whether the mod menu Activity is registered
- APK size sanity check
- Config and overlay verification
