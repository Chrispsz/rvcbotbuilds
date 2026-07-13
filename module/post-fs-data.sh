#!/system/bin/sh
# RVCBotBuilds post-fs-data
# ============================================
# Runs early in boot (before zygote).
# Removes Play Store from Magisk denylist
# so Zygisk can inject into it (needed for
# zygisk-detach to work).
# ============================================

# Remove Play Store from denylist (helps Zygisk)
magisk --denylist rm com.android.vending 2>/dev/null || :

# Also remove patched apps from denylist (if user added them)
for pkg in com.google.android.youtube com.google.android.apps.youtube.music; do
        magisk --denylist rm "$pkg" 2>/dev/null || :
done
