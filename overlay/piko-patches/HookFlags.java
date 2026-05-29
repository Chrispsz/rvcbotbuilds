/*
 * Copyright (C) 2025 piko <https://github.com/crimera/piko>
 *
 * See the included NOTICE file for GPLv3 §7(b) terms that apply to this code.
 *
 * Modified by Chrispsz — simplified to patches-only, removed JSON override
 *
 * FLAG POLICY:
 *   Only flags REQUIRED by piko patches are hardcoded here.
 *   No JSON loading — Instagram already has its own importer
 *   accessible from the mod menu (Developer options → Import overrides).
 *
 *   This approach is more stable because:
 *   - Fewer moving parts = fewer things that can break
 *   - Hardcoded flags are verified against real Instagram IDs
 *   - No file I/O on the critical config check path
 *   - Users who need extra flags can use Instagram's built-in importer
 */


package app.morphe.extension.instagram.patches;

import java.util.Map;
import java.util.HashMap;

import app.morphe.extension.crimera.PikoUtils;
import app.morphe.extension.instagram.entity.DeveloperOptions;
import app.morphe.extension.instagram.entity.DeveloperOptionsItem;
import app.morphe.extension.instagram.utils.Pref;

public class HookFlags {
    private static Map<String, Boolean> BOOL_FLAGS = new HashMap<>();
    private static DeveloperOptions developerOptions = new DeveloperOptions();

    // ============================================================
    // PIKO PATCH FLAGS — Required by piko patches to work correctly
    // These are the ONLY flags that get overridden automatically.
    // Users who need additional flags should use Instagram's
    // built-in importer: Mod Settings → Developer options → Import
    // ============================================================

    private static void contactPermissionConsentFlags() {
        BOOL_FLAGS.put("56295::14", false);
        BOOL_FLAGS.put("56295::15", false);
        BOOL_FLAGS.put("56295::29", false);
        BOOL_FLAGS.put("56295::30", false);
    }

    private static void simpleOverflowMenuFlags() {
        BOOL_FLAGS.put("104772::0", false);
        BOOL_FLAGS.put("104772::1", false);
        BOOL_FLAGS.put("104772::2", false);
        BOOL_FLAGS.put("104772::6", false);
    }

    private static void adsFlags() {
        // Core ad flags from piko source — required by DisableAds patch
        BOOL_FLAGS.put("58206::0", false);   // is_acp_enabled
        BOOL_FLAGS.put("72396::0", false);   // is_mae_exclusion_feed_enabled
        BOOL_FLAGS.put("78046::0", false);   // is_mae_exclusion_feed_enabled (alt)
        BOOL_FLAGS.put("78046::9", false);   // enable_no_invalidation_reason_for_mae_exclusion
        BOOL_FLAGS.put("79181::0", false);   // ig_reels_ads_1x2_explore_halc_android::is_enabled
        BOOL_FLAGS.put("110800::0", false);  // ig_android_controller_migration::use_v2_controller
    }

    private static void employeeOptionsFlags() {
        if(Pref.enableEmployeeOptions()){
            BOOL_FLAGS.put("28538::0", true);
        }else{
            BOOL_FLAGS.put("28538::0", false);
        }
    }

    public static void load() {
        contactPermissionConsentFlags();
        simpleOverflowMenuFlags();
        adsFlags();
        employeeOptionsFlags();

        PikoUtils.logger("HookFlags: Loaded " + BOOL_FLAGS.size() + " hardcoded patch flags");
    }

    public static Boolean handleBoolFlags(long mobileConfigSpecifier) {
        try {
            DeveloperOptionsItem developerOptionsItem = new DeveloperOptionsItem(mobileConfigSpecifier);
            String configId = developerOptionsItem.getConfigId();

            Boolean result = BOOL_FLAGS.getOrDefault(configId, null);
            if (result != null) {
                PikoUtils.logger("HookFlags: Override " + configId + " = " + result);
            }
            return result;
        } catch (Exception e) {
            PikoUtils.logger(e);
        }
        return null;
    }

    /**
     * Dump all current flags to logcat. Called from debug tools.
     */
    public static void dumpFlags() {
        PikoUtils.logger("=== HookFlags Dump ===");
        PikoUtils.logger("Patch flags (" + BOOL_FLAGS.size() + "):");
        for (Map.Entry<String, Boolean> entry : BOOL_FLAGS.entrySet()) {
            PikoUtils.logger("  " + entry.getKey() + " = " + entry.getValue());
        }
        PikoUtils.logger("=== End Dump ===");
    }

}
