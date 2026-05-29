/*
 * Copyright (C) 2026 piko <https://github.com/crimera/piko>
 *
 * See the included NOTICE file for GPLv3 §7(b) terms that apply to this code.
 *
 * RVCArise overlay: WelcomeMessage with OTA auto-check.
 * DebugReceiver removed — ADB debug is not needed.
 */

package app.morphe.extension.instagram.patches;

import android.app.Activity;
import android.content.Context;

import app.morphe.extension.instagram.utils.Pref;
import app.morphe.extension.shared.Logger;

@SuppressWarnings("unused")
public class WelcomeMessage {

    public static void openWelcomeMessage(Context context) {
        try {
            // Mark first time as seen (no welcome dialog)
            Pref.setFirstTimePiko(false);
        } catch (Exception ex) {
            Logger.printException(() -> "openWelcomeMessage: setFirstTimePiko failure", ex);
        }

        // Silent auto-check for OTA updates (48h cooldown, no dialog if up-to-date)
        try {
            if (context instanceof Activity) {
                OtaUpdater.autoCheck((Activity) context);
            }
        } catch (Exception ex) {
            // Never crash the app for an OTA check
            Logger.printException(() -> "OTA autoCheck failure", ex);
        }
    }
}
