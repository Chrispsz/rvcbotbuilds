/*
 * Copyright (C) 2025 piko <https://github.com/crimera/piko>
 *
 * See the included NOTICE file for GPLv3 §7(b) terms that apply to this code.
 */


package app.morphe.extension.instagram.constants.translations;

public class StringsHindi extends DefaultStrings {
    public StringsHindi() {
        this.PIKO_SETTINGS_TITLE = "Mod सेटिंग्स";
        this.CATEGORY_ADS = "विज्ञापन";
        this.DISABLE_ADS = "विज्ञापन बंद करें";
        this.HIDE_SUGEESTED_CONTENT = "सुझाई गई सामग्री छिपाएँ";
        this.HIDE_SUGEESTED_CONTENT_DESC = "सुझाई गई कहानियों, रील्स और थ्रेड्स को छिपाता है (सुझाई गई पोस्ट्स फिर भी दिखाई देंगी)";

        this.MORE_PROFILE_OPTIONS = "प्रोफ़ाइल के और विकल्प";

        // Debug tools
        this.DEBUG_DUMP_FLAGS = "फ्लैग को logcat में डंप करें";
        this.DEBUG_DUMP_FLAGS_DESC = "सभी वर्तमान MetaConfig ओवरराइड को logcat में लिखता है (adb logcat -s ModDebug)";
        this.DEBUG_EXPORT_DIAG = "डायग्नोस्टिक्स निर्यात करें";
        this.DEBUG_EXPORT_DIAG_DESC = "Mod स्थिति, सेटिंग्स और OTA जानकारी को /sdcard/Android/media/ में एक फ़ाइल में सहेजता है";
        this.DEBUG_ADB_HELP = "ADB डीबग कमांड";
        this.DEBUG_ADB_HELP_DESC = "adb shell am broadcast -a app.morphe.extension.instagram.DEBUG --es command <cmd>";

    }
}
