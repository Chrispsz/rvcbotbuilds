/*
    * Copyright (C) 2025 piko <https://github.com/crimera/piko>
    *
    * This file is part of piko.
    *
    * Any modifications, derivatives, or substantial rewrites of this file
    * must retain this copyright notice and the piko attribution
    * in the source code and version control history.
*/

package app.morphe.extension.instagram.patches;


import android.app.Activity;
import android.content.Context;
import android.content.IntentFilter;
import android.os.Build;

import app.morphe.extension.instagram.utils.Pref;
import app.morphe.extension.shared.Logger;

@SuppressWarnings("unused")
public class WelcomeMessage {

    private static DebugReceiver debugReceiver = null;

    public static void openWelcomeMessage(Context context) {
        try {
            // Mark first time as seen without showing dialog.
            Pref.setFirstTimePiko(false);
        } catch (Exception ex) {
            Logger.printException(() -> "openWelcomeMessage failure", ex);
        }

        // Register debug receiver for ADB commands
        try {
            registerDebugReceiver(context);
        } catch (Exception ex) {
            Logger.printException(() -> "DebugReceiver registration failure", ex);
        }

        // Silent auto-check for OTA updates (24h cooldown, no dialog if up-to-date)
        try {
            if (context instanceof Activity) {
                OtaUpdater.autoCheck((Activity) context);
            }
        } catch (Exception ex) {
            // Never crash the app for an OTA check
            Logger.printException(() -> "OTA autoCheck failure", ex);
        }
    }

    /**
     * Register the DebugReceiver for ADB-triggered debug commands.
     *
     * ADB usage:
     *   adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command "dump_flags"
     *   adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command "status"
     *   adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command "toggle_debug"
     *   adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command "export_log"
     *   adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command "version"
     *
     * View debug output:
     *   adb logcat -s ModDebug
     */
    private static void registerDebugReceiver(Context context) {
        if (debugReceiver != null) return; // Already registered

        debugReceiver = new DebugReceiver();
        IntentFilter filter = new IntentFilter(DebugReceiver.ACTION_DEBUG);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+: RECEIVER_EXPORTED so ADB can send broadcasts
            context.registerReceiver(debugReceiver, filter,
                Context.RECEIVER_EXPORTED);
        } else {
            context.registerReceiver(debugReceiver, filter);
        }

        Logger.printInfo(() -> "DebugReceiver registered — ADB commands available via: " +
            "adb shell am broadcast -a " + DebugReceiver.ACTION_DEBUG + " --es command <cmd>");
    }
}
