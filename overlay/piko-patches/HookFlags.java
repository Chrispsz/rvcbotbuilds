/*
 * Copyright (C) 2026 piko <https://github.com/crimera/piko>
 *
 * See the included NOTICE file for GPLv3 §7(b) terms that apply to this code.
 *
 * Modified by Chrispsz — added JSON override loading, preset flags, OTA support
 */


package app.morphe.extension.instagram.patches;

import android.content.Context;
import android.os.Environment;

import java.io.File;
import java.util.Map;
import java.util.HashMap;
import java.util.Iterator;

import org.json.JSONObject;

import app.morphe.extension.crimera.PikoUtils;
import app.morphe.extension.instagram.entity.DeveloperOptions;
import app.morphe.extension.instagram.entity.DeveloperOptionsItem;
import app.morphe.extension.instagram.utils.Pref;

public class HookFlags {
    private static Map<String, Boolean> BOOL_FLAGS = new HashMap<>();
    private static Map<String, Boolean> JSON_FLAGS = new HashMap<>();
    private static DeveloperOptions developerOptions = new DeveloperOptions();

    // ============================================================
    // EXISTING HARDCODED FLAGS (from original piko patches)
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
        BOOL_FLAGS.put("110800::0", false);
    }

    private static void employeeOptionsFlags() {
        if(Pref.enableEmployeeOptions()){
            BOOL_FLAGS.put("28538::0", true);
        }else{
            BOOL_FLAGS.put("28538::0", false);
        }
    }

    // ============================================================
    // PRESET FLAGS — Minimal safe set for crash testing
    // Only stories crash fix + JSON override support
    // All other flags available via mc_overrides.json (no-root)
    // ============================================================

    private static void presetFlags() {

        // ==== STORIES CRASH FIX (must be TRUE — prevents crash on v430+) ====
        BOOL_FLAGS.put("92643::0", true);    // stories_gallery_video_segment
        BOOL_FLAGS.put("59117::0", true);    // stories_video_clipping_edit
        BOOL_FLAGS.put("69238::0", true);    // stories_rewind_composer

        // NOTE: All other flags REMOVED for crash diagnosis.
        // If the profile crash is gone, flags were the cause.
        // If the profile crash persists, the issue is elsewhere (OtaUpdater, 
        // overlay code, or patch incompatibility with Instagram version).
        //
        // Users can still add custom flags via mc_overrides.json:
        // /sdcard/Android/media/com.instagram.android/mc_overrides.json
    }

    // ============================================================
    // JSON OVERRIDE LOADING
    // Reads mc_overrides.json from multiple locations:
    // Priority 1: External media storage (no-root accessible)
    //   /sdcard/Android/media/com.instagram.android/mc_overrides.json
    // Priority 2: Internal app storage (Instagram's native MetaConfig)
    //   /data/data/com.instagram.android/files/mobileconfig/mc_overrides.json
    // JSON flags override hardcoded BOOL_FLAGS
    // ============================================================

    private static void loadJsonOverrides() {
        try {
            Context ctx = PikoUtils.getContext();
            if (ctx == null) return;

            String json = null;

            // Priority 1: /sdcard/Android/media/com.instagram.android/mc_overrides.json
            // Accessible WITHOUT root on Android 11+
            File externalMediaDir = new File(
                Environment.getExternalStorageDirectory(),
                "Android/media/" + ctx.getPackageName()
            );
            File externalFile = new File(externalMediaDir, "mc_overrides.json");
            if (externalFile.exists()) {
                json = PikoUtils.readFile(externalFile);
            }

            // Priority 2: Internal /files/mobileconfig/mc_overrides.json
            // Used by Instagram's native MetaConfig editor
            if (json == null) {
                File internalDir = new File(ctx.getFilesDir(), "mobileconfig");
                File internalFile = new File(internalDir, "mc_overrides.json");
                if (internalFile.exists()) {
                    json = PikoUtils.readFile(internalFile);
                }
            }

            if (json != null && !json.isEmpty()) {
                parseJsonOverrides(json);
            }
        } catch (Exception e) {
            PikoUtils.logger(e);
        }
    }

    private static void parseJsonOverrides(String json) {
        try {
            JSONObject obj = new JSONObject(json);
            java.util.Iterator<String> keys = obj.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                try {
                    boolean value = obj.getBoolean(key);
                    JSON_FLAGS.put(key, value);
                } catch (Exception ignored) {
                    // Skip non-boolean values
                }
            }
        } catch (Exception e) {
            PikoUtils.logger(e);
        }
    }

    /**
     * Reload config from JSON files. Called from settings UI
     * after user updates mc_overrides.json externally.
     */
    public static void reloadConfig() {
        JSON_FLAGS.clear();
        loadJsonOverrides();
    }

    public static void load() {
        // Load JSON overrides (they take priority over hardcoded flags)
        loadJsonOverrides();
    }

    public static Boolean handleBoolFlags(long mobileConfigSpecifier) {
        try {
            DeveloperOptionsItem developerOptionsItem = new DeveloperOptionsItem(mobileConfigSpecifier);
            String configId = developerOptionsItem.getConfigId();

            // JSON overrides have highest priority
            Boolean jsonOverride = JSON_FLAGS.get(configId);
            if (jsonOverride != null) return jsonOverride;

            // Then hardcoded flags
            return BOOL_FLAGS.getOrDefault(configId, null);
        } catch (Exception e) {
            PikoUtils.logger(e);
        }
        return null;
    }

}
