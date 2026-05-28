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
    // PRESET FLAGS — 257 curated MetaConfig overrides
    // Loaded at startup, can be overridden by mc_overrides.json
    // Priority: external JSON > internal JSON > hardcoded
    // ============================================================

    private static void presetFlags() {
        // ---- Ads & Sponsored Content ----
        BOOL_FLAGS.put("58206::0", false);   // is_acp_enabled
        BOOL_FLAGS.put("72396::0", false);   // is_mae_exclusion_feed_enabled
        BOOL_FLAGS.put("78046::0", false);   // is_mae_exclusion_feed_enabled (alt)
        BOOL_FLAGS.put("78046::9", false);   // enable_no_invalidation_reason_for_mae_exclusion
        BOOL_FLAGS.put("79181::0", false);   // ig_reels_ads_1x2_explore_halc_android::is_enabled
        BOOL_FLAGS.put("45216::0", false);   // ig_android_ad_impression_backtest
        BOOL_FLAGS.put("54979::0", false);   // ig_android_hashtag_follow_suggestions
        BOOL_FLAGS.put("66623::0", false);   // ig_android_suggested_users_background
        BOOL_FLAGS.put("91544::0", false);   // ig_android_feed_ads_peek
        BOOL_FLAGS.put("93014::0", false);   // ig_android_feed_promoted_posts
        BOOL_FLAGS.put("42161::0", false);   // ig_android_stories_ad_cta_sheet
        BOOL_FLAGS.put("42463::0", false);   // ig_android_stories_ad_media_augmentation
        BOOL_FLAGS.put("44841::0", false);   // ig_android_stories_ad_suggested_reels
        BOOL_FLAGS.put("54840::0", false);   // ig_android_explore_ads
        BOOL_FLAGS.put("61769::0", false);   // ig_android_reels_ads
        BOOL_FLAGS.put("63526::0", false);   // ig_android_profile_ads
        BOOL_FLAGS.put("67258::0", false);   // ig_android_search_ads
        BOOL_FLAGS.put("71693::0", false);   // ig_android_discover_people_ads

        // ---- Analytics & Tracking ----
        BOOL_FLAGS.put("4177::0", false);    // ig_android_analytics_data_sampling
        BOOL_FLAGS.put("9125::0", false);    // ig_android_analytics_heartbeat
        BOOL_FLAGS.put("14750::0", false);   // ig_android_analytics_app_logging
        BOOL_FLAGS.put("23963::0", false);   // ig_android_qe_logging
        BOOL_FLAGS.put("30536::0", false);   // ig_android_analytics_network_trace
        BOOL_FLAGS.put("39560::0", false);   // ig_android_device_detection
        BOOL_FLAGS.put("47888::0", false);   // ig_android_felix_logging
        BOOL_FLAGS.put("54980::0", false);   // ig_android_login_activity_logging
        BOOL_FLAGS.put("62294::0", false);   // ig_android_exoplayer_analytics
        BOOL_FLAGS.put("74139::0", false);   // ig_android_unified_analytics
        BOOL_FLAGS.put("83014::0", false);   // ig_android_perf_analytics
        BOOL_FLAGS.put("91088::0", false);   // ig_android_session_logging

        // ---- Developer Options ----
        BOOL_FLAGS.put("28538::0", true);    // ig_android_employee_options::is_enabled

        // ---- Stories (CRASH FIX: 92643, 59117, 69238 must be TRUE) ----
        BOOL_FLAGS.put("92643::0", true);    // ig_android_stories_gallery_video_segment
        BOOL_FLAGS.put("59117::0", true);    // ig_android_stories_video_clipping_edit
        BOOL_FLAGS.put("69238::0", true);    // ig_android_stories_rewind_composer
        BOOL_FLAGS.put("10167::0", false);   // ig_android_stories_video_flip_toggle
        BOOL_FLAGS.put("12755::0", true);    // ig_android_stories_tts
        BOOL_FLAGS.put("18209::0", true);    // ig_android_stories_share_to_facebook_default
        BOOL_FLAGS.put("21307::0", false);   // ig_android_stories_suggested_highlights
        BOOL_FLAGS.put("28436::0", false);   // ig_android_stories_ad_recommendation_share
        BOOL_FLAGS.put("31933::0", true);    // ig_android_stories_save_to_camera_roll
        BOOL_FLAGS.put("36832::0", false);   // ig_android_stories_music_overlay_sticker
        BOOL_FLAGS.put("39516::0", false);   // ig_android_stories_suggested_responses
        BOOL_FLAGS.put("42879::0", true);    // ig_android_stories_web_upload
        BOOL_FLAGS.put("46480::0", false);   // ig_android_stories_live_questions
        BOOL_FLAGS.put("48989::0", true);    // ig_android_stories_debug_info
        BOOL_FLAGS.put("51903::0", false);   // ig_android_stories_auto_archive
        BOOL_FLAGS.put("55291::0", true);    // ig_android_stories_gallery_scroll_optimization
        BOOL_FLAGS.put("59171::0", false);   // ig_android_stories_reaction
        BOOL_FLAGS.put("62636::0", true);    // ig_android_stories_tray_overflow_tooltip
        BOOL_FLAGS.put("68176::0", false);   // ig_android_stories_boost_post
        BOOL_FLAGS.put("72310::0", true);    // ig_android_stories_reel_clips
        BOOL_FLAGS.put("79309::0", false);   // ig_android_stories_collaborative
        BOOL_FLAGS.put("83219::0", true);    // ig_android_stories_fundraiser_sticker
        BOOL_FLAGS.put("87844::0", false);   // ig_android_stories_ai_stickers
        BOOL_FLAGS.put("91577::0", true);    // ig_android_stories_share_sheet_improvements

        // ---- Feed ----
        BOOL_FLAGS.put("9050::0", false);    // ig_android_feed_chaining
        BOOL_FLAGS.put("13159::0", false);   // ig_android_feed_long_press_overlay
        BOOL_FLAGS.put("16661::0", false);   // ig_android_feed_reshare_to_story
        BOOL_FLAGS.put("21302::0", false);   // ig_android_feed_hide_polls
        BOOL_FLAGS.put("25243::0", false);   // ig_android_feed_suggested_communities
        BOOL_FLAGS.put("29334::0", false);   // ig_android_feed_post_to_facebook
        BOOL_FLAGS.put("33101::0", false);   // ig_android_feed_realtime_comments
        BOOL_FLAGS.put("38156::0", false);   // ig_android_feed_inline_composer
        BOOL_FLAGS.put("42619::0", false);   // ig_android_feed_location_sticker
        BOOL_FLAGS.put("47294::0", false);   // ig_android_feed_interest_discovery
        BOOL_FLAGS.put("51550::0", false);   // ig_android_feed_post_boost
        BOOL_FLAGS.put("56048::0", false);   // ig_android_feed_reel_raven
        BOOL_FLAGS.put("61402::0", false);   // ig_android_feed_auto_share_to_facebook
        BOOL_FLAGS.put("65927::0", false);   // ig_android_feed_cta_sheet
        BOOL_FLAGS.put("71283::0", false);   // ig_android_feed_comment_guidance
        BOOL_FLAGS.put("76490::0", false);   // ig_android_feed_shopping
        BOOL_FLAGS.put("81634::0", false);   // ig_android_feed_branded_content
        BOOL_FLAGS.put("86073::0", false);   // ig_android_feed_product_sticker
        BOOL_FLAGS.put("91206::0", false);   // ig_android_feed_collab_posts

        // ---- Reels ----
        BOOL_FLAGS.put("3311::0", false);    // ig_android_reels_overview
        BOOL_FLAGS.put("6621::0", false);    // ig_android_reels_suggested_clips
        BOOL_FLAGS.put("10169::0", false);   // ig_android_reels_remix
        BOOL_FLAGS.put("14128::0", false);   // ig_android_reels_templates
        BOOL_FLAGS.put("18991::0", false);   // ig_android_reels_audio_browser
        BOOL_FLAGS.put("23081::0", false);   // ig_android_reels_share_to_story
        BOOL_FLAGS.put("28374::0", false);   // ig_android_reels_alignment
        BOOL_FLAGS.put("32789::0", false);   // ig_android_reels_dual_capture
        BOOL_FLAGS.put("37650::0", false);   // ig_android_reels_green_screen
        BOOL_FLAGS.put("41362::0", false);   // ig_android_reels_interactive_effects
        BOOL_FLAGS.put("45716::0", false);   // ig_android_reels_audio_discovery
        BOOL_FLAGS.put("50235::0", false);   // ig_android_reels_collab_remix
        BOOL_FLAGS.put("55312::0", false);   // ig_android_reels_shop_clips
        BOOL_FLAGS.put("59443::0", false);   // ig_android_reels_comment_pivot
        BOOL_FLAGS.put("63791::0", false);   // ig_android_reels_gift_cards
        BOOL_FLAGS.put("68455::0", false);   // ig_android_reels_qr_sticker
        BOOL_FLAGS.put("73916::0", false);   // ig_android_reels_3d_effects
        BOOL_FLAGS.put("78217::0", false);   // ig_android_reels_like_animation
        BOOL_FLAGS.put("83152::0", false);   // ig_android_reels_countdown_sticker
        BOOL_FLAGS.put("87631::0", false);   // ig_android_reels_hashtag_sticker
        BOOL_FLAGS.put("92144::0", false);   // ig_android_reels_mention_sticker

        // ---- DM / Messaging ----
        BOOL_FLAGS.put("5290::0", false);    // ig_android_dm_message_requests
        BOOL_FLAGS.put("9830::0", true);     // ig_android_dm_reactions
        BOOL_FLAGS.put("14533::0", false);   // ig_android_dm_suggested_replies
        BOOL_FLAGS.put("19255::0", true);    // ig_android_dm_voice_messages
        BOOL_FLAGS.put("24103::0", false);   // ig_android_dm_minishop
        BOOL_FLAGS.put("29150::0", true);    // ig_android_dm_cross_app_messaging
        BOOL_FLAGS.put("33920::0", false);   // ig_android_dm_group_polls
        BOOL_FLAGS.put("38514::0", true);    // ig_android_dm_chat_threads_v2
        BOOL_FLAGS.put("43122::0", false);   // ig_android_dm_music_messaging
        BOOL_FLAGS.put("47855::0", false);   // ig_android_dm_ridealong
        BOOL_FLAGS.put("52134::0", true);    // ig_android_dm_reply_suggestions
        BOOL_FLAGS.put("56992::0", false);   // ig_android_dm_group_story_sharing
        BOOL_FLAGS.put("61428::0", false);   // ig_android_dm_business_links
        BOOL_FLAGS.put("66211::0", false);   // ig_android_dm_ai_agent
        BOOL_FLAGS.put("71025::0", false);   // ig_android_dm_pay
        BOOL_FLAGS.put("75830::0", false);   // ig_android_dm_status_updates
        BOOL_FLAGS.put("80417::0", true);    // ig_android_dm_persistent_notification
        BOOL_FLAGS.put("85362::0", false);   // ig_android_dm_sticker_search
        BOOL_FLAGS.put("90128::0", false);   // ig_android_dm_collab_mode

        // ---- Explore / Discover ----
        BOOL_FLAGS.put("2725::0", false);    // ig_android_explore_commerce
        BOOL_FLAGS.put("7392::0", false);    // ig_android_explore_interests
        BOOL_FLAGS.put("12033::0", false);   // ig_android_explore_reels_tab
        BOOL_FLAGS.put("16821::0", false);   // ig_android_explore_shopping
        BOOL_FLAGS.put("21618::0", false);   // ig_android_explore_events
        BOOL_FLAGS.put("26550::0", false);   // ig_android_explore_ig_tv
        BOOL_FLAGS.put("31447::0", false);   // ig_android_explore_guides
        BOOL_FLAGS.put("36258::0", false);   // ig_android_explore_map
        BOOL_FLAGS.put("41093::0", false);   // ig_android_explore_fundraiser
        BOOL_FLAGS.put("45903::0", false);   // ig_android_explore_topic_filter

        // ---- Profile / Account ----
        BOOL_FLAGS.put("3751::0", true);     // ig_android_profile_follow_back_indicator
        BOOL_FLAGS.put("8420::0", true);     // ig_android_profile_edit_options
        BOOL_FLAGS.put("13260::0", false);   // ig_android_profile_discover_people
        BOOL_FLAGS.put("18132::0", true);    // ig_android_profile_insights_v2
        BOOL_FLAGS.put("22745::0", false);   // ig_android_profile_suggested_accounts
        BOOL_FLAGS.put("27416::0", true);    // ig_android_profile_link_in_bio
        BOOL_FLAGS.put("32109::0", false);   // ig_android_profile_shop_section
        BOOL_FLAGS.put("36817::0", false);   // ig_android_profile_gift_cards
        BOOL_FLAGS.put("41534::0", true);    // ig_android_profile_presence_indicator
        BOOL_FLAGS.put("46210::0", false);   // ig_android_profile_professional_dashboard
        BOOL_FLAGS.put("50982::0", true);    // ig_android_profile_category_tagging
        BOOL_FLAGS.put("55766::0", false);   // ig_android_profile_subscription
        BOOL_FLAGS.put("60493::0", false);   // ig_android_profile_branded_content_tag
        BOOL_FLAGS.put("65117::0", true);    // ig_android_profile_close_friends
        BOOL_FLAGS.put("69814::0", false);   // ig_android_profile_sponsored_label
        BOOL_FLAGS.put("74536::0", true);    // ig_android_profile_mutual_followers
        BOOL_FLAGS.put("79208::0", false);   // ig_android_profile_auto_archive
        BOOL_FLAGS.put("83962::0", true);    // ig_android_profile_story_highlights_count
        BOOL_FLAGS.put("88741::0", false);   // ig_android_profile_collaborative_collection

        // ---- Image / Video Quality ----
        BOOL_FLAGS.put("4399::0", true);     // ig_android_max_image_quality
        BOOL_FLAGS.put("9127::0", true);     // ig_android_upload_quality_boost
        BOOL_FLAGS.put("13928::0", true);    // ig_android_video_quality_boost
        BOOL_FLAGS.put("18655::0", true);    // ig_android_image_decode_optimization
        BOOL_FLAGS.put("23417::0", true);    // ig_android_image_preload_high_res
        BOOL_FLAGS.put("28163::0", true);    // ig_android_video_preload
        BOOL_FLAGS.put("32944::0", true);    // ig_android_image_cache_full_res
        BOOL_FLAGS.put("37612::0", true);    // ig_android_camera_api_v2
        BOOL_FLAGS.put("42367::0", true);    // ig_android_heif_upload
        BOOL_FLAGS.put("47130::0", true);    // ig_android_hd_video_upload
        BOOL_FLAGS.put("51892::0", true);    // ig_android_image_proxy_bypass
        BOOL_FLAGS.put("56633::0", true);    // ig_android_video_streaming_quality
        BOOL_FLAGS.put("61378::0", true);    // ig_android_progressive_jpeg
        BOOL_FLAGS.put("66105::0", true);    // ig_android_webp_upload

        // ---- Navigation / UI ----
        BOOL_FLAGS.put("1625::0", false);    // ig_android_nav_reels_tab
        BOOL_FLAGS.put("6307::0", false);    // ig_android_nav_shop_tab
        BOOL_FLAGS.put("11038::0", false);   // ig_android_nav_discover_people
        BOOL_FLAGS.put("15819::0", true);    // ig_android_nav_search_icon
        BOOL_FLAGS.put("20542::0", false);   // ig_android_nav_create_shortcut
        BOOL_FLAGS.put("25308::0", true);    // ig_android_nav_bottom_sheet
        BOOL_FLAGS.put("30061::0", false);   // ig_android_nav_notifications_badge
        BOOL_FLAGS.put("34827::0", false);   // ig_android_nav_activity_feed
        BOOL_FLAGS.put("39572::0", true);    // ig_android_nav_dark_theme
        BOOL_FLAGS.put("44310::0", false);   // ig_android_nav_add_post_button
        BOOL_FLAGS.put("49088::0", false);   // ig_android_nav_igtv_button
        BOOL_FLAGS.put("53833::0", true);    // ig_android_nav_swipe_navigation
        BOOL_FLAGS.put("58591::0", false);   // ig_android_nav_lives_badge
        BOOL_FLAGS.put("63314::0", true);    // ig_android_nav_elegant_tabs
        BOOL_FLAGS.put("68056::0", false);   // ig_android_nav_notes_badge
        BOOL_FLAGS.put("72801::0", true);    // ig_android_nav_stories_ring
        BOOL_FLAGS.put("77549::0", false);   // ig_android_nav_collab_button

        // ---- Security / Privacy ----
        BOOL_FLAGS.put("2117::0", false);    // ig_android_screenshot_detection
        BOOL_FLAGS.put("6843::0", false);    // ig_android_typing_indicator
        BOOL_FLAGS.put("11616::0", false);   // ig_android_presence_status
        BOOL_FLAGS.put("16395::0", false);   // ig_android_last_active
        BOOL_FLAGS.put("21084::0", true);    // ig_android_login_verification
        BOOL_FLAGS.put("25830::0", false);   // ig_android_read_receipts
        BOOL_FLAGS.put("30567::0", true);    // ig_android_secure_storage
        BOOL_FLAGS.put("35314::0", false);   // ig_android_data_saver
        BOOL_FLAGS.put("40052::0", true);    // ig_android_two_factor_auth
        BOOL_FLAGS.put("44796::0", false);   // ig_android_third_party_analytics
        BOOL_FLAGS.put("49540::0", true);    // ig_android_hierarchical_keychain
        BOOL_FLAGS.put("54287::0", false);   // ig_android_location_tracking
        BOOL_FLAGS.put("59023::0", true);    // ig_android_certificate_pinning
        BOOL_FLAGS.put("63769::0", false);   // ig_android_device_fingerprint
        BOOL_FLAGS.put("68515::0", false);   // ig_android_app_tracking_transparency
        BOOL_FLAGS.put("73260::0", true);    // ig_android_encrypted_push
        BOOL_FLAGS.put("78004::0", false);   // ig_android_contacts_upload
        BOOL_FLAGS.put("82750::0", true);    // ig_android_biometric_lock
        BOOL_FLAGS.put("87496::0", false);   // ig_android_camera_permissions
        BOOL_FLAGS.put("92241::0", false);   // ig_android_microphone_permissions

        // ---- Notifications ----
        BOOL_FLAGS.put("3443::0", false);    // ig_android_notification_business_messages
        BOOL_FLAGS.put("8172::0", false);    // ig_android_notification_live_videos
        BOOL_FLAGS.put("12944::0", false);   // ig_android_notification_reels
        BOOL_FLAGS.put("17681::0", false);   // ig_android_notification_shopping
        BOOL_FLAGS.put("22413::0", false);   // ig_android_notification_fundraiser
        BOOL_FLAGS.put("27152::0", false);   // ig_android_notification_group_requests
        BOOL_FLAGS.put("31896::0", false);   // ig_android_notification_suggestions
        BOOL_FLAGS.put("36640::0", false);   // ig_android_notification_first_post
        BOOL_FLAGS.put("41384::0", false);   // ig_android_notification_weekly_digest
        BOOL_FLAGS.put("46128::0", false);   // ig_android_notification_product_launch
        BOOL_FLAGS.put("50872::0", false);   // ig_android_notification_creator
        BOOL_FLAGS.put("55616::0", false);   // ig_android_notification_reminders
        BOOL_FLAGS.put("60360::0", false);   // ig_android_notification_anniversary

        // ---- Sharing / Links ----
        BOOL_FLAGS.put("4761::0", true);     // ig_android_sanitize_share_links
        BOOL_FLAGS.put("9510::0", true);     // ig_android_open_links_externally
        BOOL_FLAGS.put("14249::0", false);   // ig_android_share_to_whatsapp
        BOOL_FLAGS.put("18993::0", false);   // ig_android_share_to_messenger
        BOOL_FLAGS.put("23730::0", true);    // ig_android_share_sheet_v2
        BOOL_FLAGS.put("28476::0", true);    // ig_android_copy_link_share
        BOOL_FLAGS.put("33215::0", false);   // ig_android_share_to_story
        BOOL_FLAGS.put("37961::0", true);    // ig_android_deep_link_handling
        BOOL_FLAGS.put("42702::0", true);    // ig_android_clipboard_link_detection
        BOOL_FLAGS.put("47448::0", false);   // ig_android_share_tracking_params
        BOOL_FLAGS.put("52191::0", true);    // ig_android_universal_links
        BOOL_FLAGS.put("56937::0", false);   // ig_android_share_analytics

        // ---- Ephemeral Media / View Once ----
        BOOL_FLAGS.put("5843::0", true);     // ig_android_unlimited_replays
        BOOL_FLAGS.put("10590::0", true);    // ig_android_permanent_ephemeral
        BOOL_FLAGS.put("15327::0", true);    // ig_android_save_ephemeral_media
        BOOL_FLAGS.put("20071::0", false);   // ig_android_ephemeral_screenshot_toast
        BOOL_FLAGS.put("24810::0", true);    // ig_android_ephemeral_replay_counter
        BOOL_FLAGS.put("29554::0", true);    // ig_android_ephemeral_notification
        BOOL_FLAGS.put("34299::0", true);    // ig_android_ephemeral_gallery_save

        // ---- Camera / Creation ----
        BOOL_FLAGS.put("2224::0", true);     // ig_android_camera_dual_capture
        BOOL_FLAGS.put("6978::0", true);     // ig_android_camera_boomerang
        BOOL_FLAGS.put("11730::0", false);   // ig_android_camera_layout_flip
        BOOL_FLAGS.put("16468::0", true);    // ig_android_camera_multi_capture
        BOOL_FLAGS.put("21201::0", true);    // ig_android_camera_effects
        BOOL_FLAGS.put("25945::0", false);   // ig_android_camera_suggestions
        BOOL_FLAGS.put("30685::0", true);    // ig_android_camera_hands_free
        BOOL_FLAGS.put("35430::0", false);   // ig_android_camera_ai_suggestions
        BOOL_FLAGS.put("40172::0", true);    // ig_android_camera_superzoom
        BOOL_FLAGS.put("44918::0", true);    // ig_android_camera_music_sticker
        BOOL_FLAGS.put("49660::0", false);   // ig_android_camera_auto_caption
        BOOL_FLAGS.put("54402::0", true);    // ig_android_camera_gif_search
        BOOL_FLAGS.put("59148::0", false);   // ig_android_camera_weather_sticker

        // ---- Comments ----
        BOOL_FLAGS.put("1389::0", true);     // ig_android_comment_copy_button
        BOOL_FLAGS.put("6130::0", true);     // ig_android_comment_translation
        BOOL_FLAGS.put("10862::0", false);   // ig_android_comment_filter
        BOOL_FLAGS.put("15601::0", true);    // ig_android_comment_like_button
        BOOL_FLAGS.put("20342::0", false);   // ig_android_comment_pinned_badge
        BOOL_FLAGS.put("25083::0", false);   // ig_android_comment_guidance_prompt
        BOOL_FLAGS.put("29824::0", true);    // ig_android_comment_reply_collapse
        BOOL_FLAGS.put("34565::0", false);   // ig_android_comment_hidden_words
        BOOL_FLAGS.put("39306::0", true);    // ig_android_comment_thread_indent

        // ---- Audio / Music ----
        BOOL_FLAGS.put("3981::0", true);     // ig_android_music_in_feed
        BOOL_FLAGS.put("8724::0", true);     // ig_android_music_overlay
        BOOL_FLAGS.put("13462::0", true);    // ig_android_music_sticker
        BOOL_FLAGS.put("18201::0", false);   // ig_android_music_autoplay
        BOOL_FLAGS.put("22940::0", true);    // ig_android_music_capture
        BOOL_FLAGS.put("27681::0", true);    // ig_android_music_library_v2
        BOOL_FLAGS.put("32422::0", false);   // ig_android_music_lyrics
        BOOL_FLAGS.put("37163::0", true);    // ig_android_music_search
        BOOL_FLAGS.put("41904::0", true);    // ig_android_audio_browser

        // ---- Likes / Interactions ----
        BOOL_FLAGS.put("2853::0", false);    // ig_android_double_tap_like_post
        BOOL_FLAGS.put("7595::0", false);    // ig_android_double_tap_like_reel
        BOOL_FLAGS.put("12336::0", false);   // ig_android_double_tap_like_comment
        BOOL_FLAGS.put("17077::0", false);   // ig_android_double_tap_like_message
        BOOL_FLAGS.put("21818::0", true);    // ig_android_like_animation_change
        BOOL_FLAGS.put("26559::0", true);    // ig_android_like_count_visible

        // ---- Notes ----
        BOOL_FLAGS.put("5102::0", false);    // ig_android_notes_tray
        BOOL_FLAGS.put("9837::0", false);    // ig_android_notes_creation
        BOOL_FLAGS.put("14578::0", false);   // ig_android_notes_updates
        BOOL_FLAGS.put("19319::0", false);   // ig_android_notes_music
        BOOL_FLAGS.put("24060::0", false);   // ig_android_notes_video

        // ---- Live ----
        BOOL_FLAGS.put("4516::0", true);     // ig_android_live_anonymous
        BOOL_FLAGS.put("9251::0", false);    // ig_android_live_notifications
        BOOL_FLAGS.put("13992::0", false);   // ig_android_live_shopping
        BOOL_FLAGS.put("18733::0", true);    // ig_android_live_donation
        BOOL_FLAGS.put("23474::0", false);   // ig_android_live_guest
        BOOL_FLAGS.put("28215::0", true);    // ig_android_live_questions
        BOOL_FLAGS.put("32956::0", false);   // ig_android_live_badges

        // ---- Build / OTA ----
        BOOL_FLAGS.put("3753::0", true);     // ig_android_remove_build_expired
        BOOL_FLAGS.put("8498::0", true);     // ig_android_skip_update_check

        // ---- Misc / Extra ----
        BOOL_FLAGS.put("1061::0", true);     // ig_android_more_options_post
        BOOL_FLAGS.put("5798::0", true);     // ig_android_more_options_profile
        BOOL_FLAGS.put("10339::0", true);    // ig_android_unlock_developer_options
        BOOL_FLAGS.put("15080::0", false);   // ig_android_unlock_plus_benefits
        BOOL_FLAGS.put("19821::0", false);   // ig_android_enable_employee_options
        BOOL_FLAGS.put("24562::0", true);    // ig_android_allow_user_certificate
        BOOL_FLAGS.put("29303::0", false);   // ig_android_hide_reshare_button
        BOOL_FLAGS.put("34044::0", true);    // ig_android_remove_empty_bottom_space
        BOOL_FLAGS.put("38785::0", false);   // ig_android_view_story_mentions
        BOOL_FLAGS.put("43526::0", true);    // ig_android_follow_back_indicator
        BOOL_FLAGS.put("48267::0", false);   // ig_android_disable_discover_people
        BOOL_FLAGS.put("53008::0", true);    // ig_android_stories_audio_autoplay
        BOOL_FLAGS.put("57749::0", false);   // ig_android_disable_video_autoplay
        BOOL_FLAGS.put("62490::0", true);    // ig_android_customise_story_timestamp
        BOOL_FLAGS.put("67231::0", false);   // ig_android_disable_story_flipping
        BOOL_FLAGS.put("71972::0", true);    // ig_android_hide_navigation_feed
        BOOL_FLAGS.put("76713::0", true);    // ig_android_hide_navigation_reels
        BOOL_FLAGS.put("81454::0", true);    // ig_android_hide_navigation_direct
        BOOL_FLAGS.put("86195::0", true);    // ig_android_hide_navigation_search
        BOOL_FLAGS.put("90936::0", true);    // ig_android_hide_navigation_create
        BOOL_FLAGS.put("5433::0", true);     // ig_android_download_media
        BOOL_FLAGS.put("10174::0", true);    // ig_android_download_profile_pic
        BOOL_FLAGS.put("14915::0", true);    // ig_android_download_stories
        BOOL_FLAGS.put("19656::0", true);    // ig_android_download_reels
        BOOL_FLAGS.put("24397::0", true);    // ig_android_download_highlights
        BOOL_FLAGS.put("29138::0", true);    // ig_android_download_audio
        BOOL_FLAGS.put("33879::0", true);    // ig_android_direct_download
        BOOL_FLAGS.put("38620::0", false);   // ig_android_download_username_folder
        BOOL_FLAGS.put("43361::0", true);    // ig_android_improve_image_viewing_2048
        BOOL_FLAGS.put("48102::0", true);    // ig_android_view_stories_anonymously
        BOOL_FLAGS.put("52843::0", true);    // ig_android_view_dm_anonymously
        BOOL_FLAGS.put("57584::0", true);    // ig_android_view_live_anonymously
        BOOL_FLAGS.put("62325::0", true);    // ig_android_disable_screenshot_detection
        BOOL_FLAGS.put("67066::0", true);    // ig_android_disable_typing_status
        BOOL_FLAGS.put("71807::0", true);    // ig_android_sanitize_share_links
        BOOL_FLAGS.put("76548::0", true);    // ig_android_open_links_externally
        BOOL_FLAGS.put("81289::0", true);    // ig_android_disable_analytics
        BOOL_FLAGS.put("86030::0", true);    // ig_android_amoled_theme
        BOOL_FLAGS.put("90771::0", false);   // ig_android_hide_suggested_content
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
