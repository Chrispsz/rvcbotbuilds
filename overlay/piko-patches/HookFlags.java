/*
 * Copyright (C) 2026 piko <https://github.com/crimera/piko>
 *
 * See the included NOTICE file for GPLv3 §7(b) terms that apply to this code.
 *
 * HookFlags overlay for Chrispsz/piko fork.
 * Aligned with upstream crimera/piko dev branch.
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
        BOOL_FLAGS.put("110800::0", false);
    }

    // Called by HideSuggestedContentPatch via addFlags("suggestedContentFlags")
    private static void suggestedContentFlags() {
        BOOL_FLAGS.put("111509::3", false);
        BOOL_FLAGS.put("82771::0", false);
    }

    // Called by ProfileMoreOptionsPatch via addFlags("profileActionBarFlags")
    // (not in our 11 patches, but included for completeness)
    private static void profileActionBarFlags() {
        BOOL_FLAGS.put("81826::0", true);
    }

    private static void employeeOptionsFlags() {
        if(Pref.enableEmployeeOptions()){
            BOOL_FLAGS.put("28538::0", true);
        }else{
            BOOL_FLAGS.put("28538::0", false);
        }
    }

    /**
     * Stub for compatibility — some patches reference presetFlags.
     */
    public static void presetFlags() {
        PikoUtils.logger("HookFlags: presetFlags() called (no-op)");
    }

    /**
     * Entry point — called by SettingsPatch which injects
     * LOAD_FLAGS_DESCRIPTOR.format("load") into InstagramAppShell.onCreate.
     * Individual patches use addFlags() to inject calls at patch time.
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

    public static boolean hasFlags() {
        return !BOOL_FLAGS.isEmpty();
    }

    public static void dumpFlags() {
        PikoUtils.logger("=== HookFlags Dump ===");
        PikoUtils.logger("Patch flags (" + BOOL_FLAGS.size() + "):");
        for (Map.Entry<String, Boolean> entry : BOOL_FLAGS.entrySet()) {
            PikoUtils.logger("  " + entry.getKey() + " = " + entry.getValue());
        }
        PikoUtils.logger("=== End Dump ===");
    }
}
