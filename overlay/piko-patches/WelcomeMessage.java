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

import app.morphe.extension.instagram.utils.Pref;
import app.morphe.extension.shared.Logger;

@SuppressWarnings("unused")
public class WelcomeMessage {

    public static void openWelcomeMessage(Context context) {
        try {
            // Mark first time as seen without showing dialog.
            Pref.setFirstTimePiko(false);
        } catch (Exception ex) {
            Logger.printException(() -> "openWelcomeMessage failure", ex);
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

}
