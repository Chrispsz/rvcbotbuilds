/*
 * Debug Receiver — ADB-triggered debug commands
 *
 * Primary debug tool. Works without needing any in-app toggle.
 * Always registered on app launch by WelcomeMessage.
 *
 * All commands are logged to logcat with tag "ModDebug".
 *
 * Usage from ADB:
 *   adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command "dump_flags"
 *   adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command "toggle_debug"
 *   adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command "export_log"
 *   adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command "status"
 *   adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command "version"
 *
 * View logs:
 *   adb logcat -s ModDebug
 *
 * Copyright (C) 2025 Chrispsz
 */


package app.morphe.extension.instagram.patches;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Environment;

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.Map;

import app.morphe.extension.crimera.PikoUtils;
import app.morphe.extension.instagram.utils.Pref;
import app.morphe.extension.instagram.patches.HookFlags;
import app.morphe.extension.shared.Utils;

public class DebugReceiver extends BroadcastReceiver {

    private static final String TAG = "ModDebug";
    public static final String ACTION_DEBUG = "app.morphe.extension.instagram.DEBUG";
    private static final String EXTRA_COMMAND = "command";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (!ACTION_DEBUG.equals(intent.getAction())) return;

        String command = intent.getStringExtra(EXTRA_COMMAND);
        if (command == null || command.isEmpty()) {
            log("No command specified. Use: dump_flags, toggle_debug, export_log, status, version");
            return;
        }

        log("Command received: " + command);

        try {
            switch (command) {
                case "dump_flags":
                    dumpFlags();
                    break;
                case "toggle_debug":
                    toggleDebug(context);
                    break;
                case "export_log":
                    exportLog(context);
                    break;
                case "status":
                    showStatus(context);
                    break;
                case "version":
                    showVersion();
                    break;
                default:
                    log("Unknown command: " + command);
                    log("Available: dump_flags, toggle_debug, export_log, status, version");
            }
        } catch (Exception e) {
            StringWriter sw = new StringWriter();
            e.printStackTrace(new PrintWriter(sw));
            log("ERROR: " + sw.toString());
        }
    }

    private void dumpFlags() {
        log("=== Flag Dump ===");
        HookFlags.dumpFlags();
        log("=== Check logcat tag 'PikoUtils' for full dump ===");
    }

    private void toggleDebug(Context context) {
        SharedPreferences prefs = context.getSharedPreferences("piko_settings", Context.MODE_PRIVATE);
        boolean current = prefs.getBoolean("piko_debug", false);
        boolean newValue = !current;
        prefs.edit().putBoolean("piko_debug", newValue).apply();
        log("Mod debug: " + (newValue ? "ENABLED" : "DISABLED"));
        log("Restart Instagram for full effect");
    }

    private void exportLog(Context context) {
        try {
            File dir = new File(
                Environment.getExternalStorageDirectory(),
                "Android/media/" + context.getPackageName()
            );
            if (!dir.exists()) dir.mkdirs();

            String timestamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
            File logFile = new File(dir, "mod_debug_" + timestamp + ".log");

            StringBuilder sb = new StringBuilder();
            sb.append("=== Mod Debug Log ===\n");
            sb.append("Timestamp: ").append(timestamp).append("\n");
            sb.append("App version: ").append(Utils.getAppVersionName()).append("\n");
            sb.append("Patch version: ").append(Utils.getPatchesReleaseVersion()).append("\n");
            sb.append("Android: ").append(Build.VERSION.RELEASE).append(" (API ").append(Build.VERSION.SDK_INT).append(")\n");
            sb.append("Device: ").append(Build.MANUFACTURER).append(" ").append(Build.MODEL).append("\n");
            sb.append("\n");

            // SharedPreferences
            sb.append("=== Settings ===\n");
            SharedPreferences prefs = context.getSharedPreferences("piko_settings", Context.MODE_PRIVATE);
            for (Map.Entry<String, ?> entry : prefs.getAll().entrySet()) {
                sb.append("  ").append(entry.getKey()).append(" = ").append(entry.getValue()).append("\n");
            }
            sb.append("\n");

            // OTA prefs
            sb.append("=== OTA Info ===\n");
            SharedPreferences otaPrefs = context.getSharedPreferences("piko_ota", Context.MODE_PRIVATE);
            for (Map.Entry<String, ?> entry : otaPrefs.getAll().entrySet()) {
                sb.append("  ").append(entry.getKey()).append(" = ").append(entry.getValue()).append("\n");
            }
            sb.append("\n");

            // HookFlags dump
            sb.append("=== HookFlags ===\n");
            sb.append("Only hardcoded patch flags (no JSON loading). Users can import extra flags via Instagram's built-in importer.\n");

            FileWriter writer = new FileWriter(logFile);
            writer.write(sb.toString());
            writer.close();

            log("Log exported to: " + logFile.getAbsolutePath());
        } catch (Exception e) {
            log("Export failed: " + e.getMessage());
        }
    }

    private void showStatus(Context context) {
        log("=== Mod Status ===");
        log("App version: " + Utils.getAppVersionName());
        log("Patch version: " + Utils.getPatchesReleaseVersion());
        log("Android: " + Build.VERSION.RELEASE + " (API " + Build.VERSION.SDK_INT + ")");
        log("Device: " + Build.MANUFACTURER + " " + Build.MODEL);

        SharedPreferences prefs = context.getSharedPreferences("piko_settings", Context.MODE_PRIVATE);
        log("Debug mode: " + prefs.getBoolean("piko_debug", false));
        log("Download enabled: " + prefs.getBoolean("enable_download", true));
        log("Disable ads: " + prefs.getBoolean("disable_ads", true));
        log("Disable analytics: " + prefs.getBoolean("disable_analytics", true));

        SharedPreferences otaPrefs = context.getSharedPreferences("piko_ota", Context.MODE_PRIVATE);
        String installedTag = otaPrefs.getString("installed_tag", "unknown");
        long lastCheck = otaPrefs.getLong("last_check_ms", 0);
        log("Installed tag: " + installedTag);
        log("Last OTA check: " + (lastCheck > 0 ? new Date(lastCheck).toString() : "never"));

        log("Flag system: hardcoded patches only (use Instagram importer for extra flags)");
    }

    private void showVersion() {
        log("App: " + Utils.getAppVersionName());
        log("Patches: " + Utils.getPatchesReleaseVersion());
    }

    private static void log(String msg) {
        android.util.Log.d(TAG, msg);
    }
}
