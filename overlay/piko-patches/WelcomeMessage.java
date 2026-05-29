/*
    * Copyright (C) 2026 piko <https://github.com/crimera/piko>
    *
    * This file is part of piko.
    *
    * Any modifications, derivatives, or substantial rewrites of this file
    * must retain this copyright notice and the piko attribution
    * in the source code and version control history.
*/

package app.morphe.extension.instagram.patches;


import android.content.Context;

import app.morphe.extension.instagram.utils.Pref;
import app.morphe.extension.shared.Logger;

@SuppressWarnings("unused")
public class WelcomeMessage {

    public static void openWelcomeMessage(Context context) {
        try {
            // Mark first time as seen without showing dialog.
            // The original code called UI.welcomeDialogBox(context) which
            // attempts to show an AlertDialog during app init — this causes
            // a crash when the context is not a valid Activity (e.g. profile screen).
            // The piko settings button already pulses on first launch, which is enough.
            Pref.setFirstTimePiko(false);
        } catch (Exception ex) {
            Logger.printException(() -> "openWelcomeMessage failure", ex);
        }
    }

}
