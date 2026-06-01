#!/usr/bin/env python3
import json
import sys
import urllib.request

tag = sys.argv[1] if len(sys.argv) > 1 else "unknown"
morphe_ver = sys.argv[2] if len(sys.argv) > 2 else ""

changelog = ""
if morphe_ver:
    try:
        url = f"https://api.github.com/repos/MorpheApp/morphe-patches/releases/tags/{morphe_ver}"
        req = urllib.request.Request(url, headers={"User-Agent": "CI"})
        data = json.loads(urllib.request.urlopen(req).read())
        changelog = data.get("body", "")[:2000]
    except Exception:
        changelog = f"See https://github.com/MorpheApp/morphe-patches/releases/tag/{morphe_ver}"

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
