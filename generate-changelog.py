#!/usr/bin/env python3
"""Generate release notes for RVCArise releases.

Usage: generate-changelog.py <tag> [morphe_version] [detach_version]
"""
import json
import sys
import urllib.request

tag = sys.argv[1] if len(sys.argv) > 1 else "unknown"
morphe_ver = sys.argv[2] if len(sys.argv) > 2 else ""
detach_ver = sys.argv[3] if len(sys.argv) > 3 else ""

changelog = ""
if morphe_ver:
    try:
        url = f"https://api.github.com/repos/MorpheApp/morphe-patches/releases/tags/{morphe_ver}"
        req = urllib.request.Request(url, headers={"User-Agent": "CI"})
        data = json.loads(urllib.request.urlopen(req).read())
        changelog = data.get("body", "")[:2500]
    except Exception:
        changelog = f"See https://github.com/MorpheApp/morphe-patches/releases/tag/{morphe_ver}"

detach_line = f"\n- Detach: zygisk-detach {detach_ver} (auto-update)" if detach_ver else "\n- Detach: zygisk-detach (auto-update)"

notes = f"""## RVCArise {tag}

### YouTube
AMOLED | Ad-free | Downloads | Swipe controls | Background play
- Theme: Pure black AMOLED
- Ads: Fully blocked (general + video)
- Downloads: External downloader integration
- Swipe: Volume & brightness gestures
- Speed: Custom playback speed
- Background: Unrestricted playback
- Clean feed: No Shorts, no suggested channels
- Module: Includes zygisk-detach

### Music
AMOLED | Ad-free | Exclusive audio | Permanent repeat
- Theme: Pure black AMOLED
- Ads: Fully blocked
- Audio: Exclusive audio-only mode
- Repeat: Always repeat tracks
- Miniplayer: Previous & next buttons
- Background: Unrestricted playback
- Module: Includes zygisk-detach

### Module Features
- Auto-detach: Blocks Play Store updates for patched apps
- Zygisk module (.so) for ARM, ARM64, x86, x86_64
- KernelSU support (ksu_profile for com.android.vending)
- Re-mounts patched APK on every boot via service.sh

### Requirements

| Format | Root? | Needs |
|--------|-------|-------|
| YouTube APK | No | [GmsCore](https://github.com/ReVanced/GmsCore/releases) |
| YouTube Module | Yes | Magisk / KernelSU |
| Music APK | No | [GmsCore](https://github.com/ReVanced/GmsCore/releases) |
| Music Module | Yes | Magisk / KernelSU |
"""

if changelog:
    notes += f"\n---\n\n### Morphe Patches {morphe_ver}\n\n{changelog}\n"

print(notes)
