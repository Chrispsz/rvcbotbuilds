/*
 * Copyright (C) 2025 piko <https://github.com/crimera/piko>
 *
 * See the included NOTICE file for GPLv3 §7(b) terms that apply to this code.
 *
 * Modified by Chrispsz — follows upstream pattern:
 *   load() is EMPTY — individual patches use addFlags() to inject
 *   calls to specific flag methods at the bytecode level.
 *
 * FLAG POLICY:
 *   Only flags REQUIRED by piko patches are hardcoded here.
 *   presetFlags() exists as a stub for compatibility with
 *   SettingsPatch.kt which calls addFlags("presetFlags").
 *   Users who need extra flags can use Instagram's built-in
 *   importer: Mod Settings → Developer options → Import
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
    //
    // How it works:
    //   load() is EMPTY. Individual patches (DisableAds, DownloadMedia,
    //   UnlockEmployeeOptions, SettingsPatch) call addFlags("methodName")
    //   which injects bytecode: invoke-static {}, HookFlags.methodName()V
    //   into load() at patch time.
    //
    //   So at runtime, load() will call whatever methods the included
    //   patches need. No need to hardcode calls in load() itself.
    // ============================================================

    /**
     * Called by SettingsPatch via addFlags("contactPermissionConsentFlags")
     * and also by the "Add settings" patch.
     */
    private static void contactPermissionConsentFlags() {
        BOOL_FLAGS.put("56295::14", false);
        BOOL_FLAGS.put("56295::15", false);
        BOOL_FLAGS.put("56295::29", false);
        BOOL_FLAGS.put("56295::30", false);
    }

    /**
     * Called by DownloadMediaPatch via addFlags("simpleOverflowMenuFlags")
     * and also by the "Add settings" patch.
     */
    private static void simpleOverflowMenuFlags() {
        BOOL_FLAGS.put("104772::0", false);
        BOOL_FLAGS.put("104772::1", false);
        BOOL_FLAGS.put("104772::2", false);
        BOOL_FLAGS.put("104772::6", false);
    }

    /**
     * Called by DisableAdsPatch via addFlags("adsFlags")
     */
    private static void adsFlags() {
        BOOL_FLAGS.put("58206::0", false);   // is_acp_enabled
        BOOL_FLAGS.put("72396::0", false);   // is_mae_exclusion_feed_enabled
        BOOL_FLAGS.put("78046::0", false);   // is_mae_exclusion_feed_enabled (alt)
        BOOL_FLAGS.put("78046::9", false);   // enable_no_invalidation_reason_for_mae_exclusion
        BOOL_FLAGS.put("79181::0", false);   // ig_reels_ads_1x2_explore_halc_android::is_enabled
        BOOL_FLAGS.put("110800::0", false);  // ig_android_controller_migration::use_v2_controller
    }

    /**
     * Called by UnlockEmployeeOptionsPatch via addFlags("employeeOptionsFlags")
     */
    private static void employeeOptionsFlags() {
        if(Pref.enableEmployeeOptions()){
            BOOL_FLAGS.put("28538::0", true);
        }else{
            BOOL_FLAGS.put("28538::0", false);
        }
    }

    /**
     * Stub for compatibility — SettingsPatch.kt calls addFlags("presetFlags")
     * which injects: invoke-static {}, HookFlags.presetFlags()V into load().
     * If this method doesn't exist, the app crashes with NoSuchMethodError.
     *
     * We don't use preset flags (users can import via Developer options instead),
     * so this is intentionally empty.
     */
    public static void presetFlags() {
        // Intentionally empty — flag overrides are handled by individual
        // flag methods above, or imported via Instagram's built-in importer.
        PikoUtils.logger("HookFlags: presetFlags() called (no-op, use Developer options to import flags)");
    }

    /**
     * Entry point — called by SettingsPatch which injects
     * LOAD_FLAGS_DESCRIPTOR.format("load") into InstagramAppShell.onCreate.
     *
     * This method is EMPTY by design. Individual patches use addFlags()
     * to inject calls to specific flag methods at the bytecode level.
     * For example:
     *   addFlags("contactPermissionConsentFlags") → injects HookFlags.contactPermissionConsentFlags()V
     *   addFlags("adsFlags")                       → injects HookFlags.adsFlags()V
     *   addFlags("presetFlags")                    → injects HookFlags.presetFlags()V
     *
     * At runtime, load() will execute all injected calls in order.
     */
    public static void load() {
        // Empty — all flag methods are injected by addFlags() calls from patches
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
