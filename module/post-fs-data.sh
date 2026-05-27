#!/system/bin/sh
# RVCBotBuilds post-fs-data
# Remove Play Store from denylist (helps Zygisk)
magisk --denylist rm com.android.vending 2>/dev/null || :
