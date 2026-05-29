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
    // PRESET FLAGS — Essential MetaConfig overrides only
    // Quality · Privacy · Ads · Crash fix · Navigation
    // Overridable via mc_overrides.json (no-root)
    // Priority: external JSON > internal JSON > hardcoded
    // ============================================================

    private static void presetFlags() {

        // ==== STORIES CRASH FIX (must be TRUE — prevents crash on v430+) ====
        BOOL_FLAGS.put("92643::0", true);    // stories_gallery_video_segment
        BOOL_FLAGS.put("59117::0", true);    // stories_video_clipping_edit
        BOOL_FLAGS.put("69238::0", true);    // stories_rewind_composer

        // ==== IMAGE / VIDEO QUALITY ====
        BOOL_FLAGS.put("4399::0", true);     // max_image_quality
        BOOL_FLAGS.put("9127::0", true);     // upload_quality_boost
        BOOL_FLAGS.put("13928::0", true);    // video_quality_boost
        BOOL_FLAGS.put("18655::0", true);    // image_decode_optimization
        BOOL_FLAGS.put("23417::0", true);    // image_preload_high_res
        BOOL_FLAGS.put("28163::0", true);    // video_preload
        BOOL_FLAGS.put("32944::0", true);    // image_cache_full_res
        BOOL_FLAGS.put("47130::0", true);    // hd_video_upload
        BOOL_FLAGS.put("51892::0", true);    // image_proxy_bypass
        BOOL_FLAGS.put("56633::0", true);    // video_streaming_quality
        BOOL_FLAGS.put("61378::0", true);    // progressive_jpeg
        BOOL_FLAGS.put("66105::0", true);    // webp_upload
        BOOL_FLAGS.put("43361::0", true);    // improve_image_viewing_2048

        // ==== DOWNLOAD MEDIA ====
        BOOL_FLAGS.put("5433::0", true);     // download_media
        BOOL_FLAGS.put("10174::0", true);    // download_profile_pic
        BOOL_FLAGS.put("14915::0", true);    // download_stories
        BOOL_FLAGS.put("19656::0", true);    // download_reels
        BOOL_FLAGS.put("24397::0", true);    // download_highlights
        BOOL_FLAGS.put("29138::0", true);    // download_audio
        BOOL_FLAGS.put("33879::0", true);    // direct_download

        // ==== ADS & SPONSORED ====
        BOOL_FLAGS.put("58206::0", false);   // is_acp_enabled
        BOOL_FLAGS.put("110800::0", false);  // ads main toggle
        BOOL_FLAGS.put("91544::0", false);   // feed_ads_peek
        BOOL_FLAGS.put("93014::0", false);   // feed_promoted_posts
        BOOL_FLAGS.put("54840::0", false);   // explore_ads
        BOOL_FLAGS.put("61769::0", false);   // reels_ads
        BOOL_FLAGS.put("63526::0", false);   // profile_ads
        BOOL_FLAGS.put("67258::0", false);   // search_ads
        BOOL_FLAGS.put("42161::0", false);   // stories_ad_cta_sheet
        BOOL_FLAGS.put("42463::0", false);   // stories_ad_media_augmentation
        BOOL_FLAGS.put("79181::0", false);   // reels_ads_explore
        BOOL_FLAGS.put("76490::0", false);   // feed_shopping

        // ==== ANALYTICS & TRACKING ====
        BOOL_FLAGS.put("4177::0", false);    // analytics_data_sampling
        BOOL_FLAGS.put("9125::0", false);    // analytics_heartbeat
        BOOL_FLAGS.put("14750::0", false);   // analytics_app_logging
        BOOL_FLAGS.put("23963::0", false);   // qe_logging
        BOOL_FLAGS.put("30536::0", false);   // analytics_network_trace
        BOOL_FLAGS.put("47888::0", false);   // felix_logging
        BOOL_FLAGS.put("62294::0", false);   // exoplayer_analytics
        BOOL_FLAGS.put("74139::0", false);   // unified_analytics
        BOOL_FLAGS.put("83014::0", false);   // perf_analytics
        BOOL_FLAGS.put("91088::0", false);   // session_logging
        BOOL_FLAGS.put("81289::0", true);    // disable_analytics

        // ==== PRIVACY ====
        BOOL_FLAGS.put("2117::0", false);    // screenshot_detection
        BOOL_FLAGS.put("6843::0", false);    // typing_indicator
        BOOL_FLAGS.put("11616::0", false);   // presence_status
        BOOL_FLAGS.put("16395::0", false);   // last_active
        BOOL_FLAGS.put("25830::0", false);   // read_receipts
        BOOL_FLAGS.put("44796::0", false);   // third_party_analytics
        BOOL_FLAGS.put("54287::0", false);   // location_tracking
        BOOL_FLAGS.put("63769::0", false);   // device_fingerprint
        BOOL_FLAGS.put("68515::0", false);   // app_tracking_transparency
        BOOL_FLAGS.put("78004::0", false);   // contacts_upload
        BOOL_FLAGS.put("62325::0", true);    // disable_screenshot_detection
        BOOL_FLAGS.put("67066::0", true);    // disable_typing_status

        // ==== NAVIGATION / UI ====
        BOOL_FLAGS.put("1625::0", false);    // hide reels tab
        BOOL_FLAGS.put("6307::0", false);    // hide shop tab
        BOOL_FLAGS.put("39572::0", true);    // dark_theme
        BOOL_FLAGS.put("86030::0", true);    // amoled_theme
        BOOL_FLAGS.put("34044::0", true);    // remove_empty_bottom_space
        BOOL_FLAGS.put("71972::0", true);    // hide_navigation_feed
        BOOL_FLAGS.put("76713::0", true);    // hide_navigation_reels
        BOOL_FLAGS.put("81454::0", true);    // hide_navigation_direct
        BOOL_FLAGS.put("86195::0", true);    // hide_navigation_search
        BOOL_FLAGS.put("90936::0", true);    // hide_navigation_create

        // ==== LINKS / SHARING ====
        BOOL_FLAGS.put("4761::0", true);     // sanitize_share_links
        BOOL_FLAGS.put("9510::0", true);     // open_links_externally
        BOOL_FLAGS.put("71807::0", true);    // sanitize_share_links (alt)
        BOOL_FLAGS.put("76548::0", true);    // open_links_externally (alt)
        BOOL_FLAGS.put("47448::0", false);   // share_tracking_params
        BOOL_FLAGS.put("56937::0", false);   // share_analytics

        // ==== BUILD / OTA ====
        BOOL_FLAGS.put("3753::0", true);     // remove_build_expired
        BOOL_FLAGS.put("8498::0", true);     // skip_update_check

        // ==== DEV OPTIONS ====
        BOOL_FLAGS.put("28538::0", true);    // employee_options (dev menu)
        BOOL_FLAGS.put("10339::0", true);    // unlock_developer_options

        // ==== MISC USEFUL ====
        BOOL_FLAGS.put("1061::0", true);     // more_options_post
        BOOL_FLAGS.put("5798::0", true);     // more_options_profile
        BOOL_FLAGS.put("24562::0", true);    // allow_user_certificate
        BOOL_FLAGS.put("90771::0", false);   // hide_suggested_content
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
