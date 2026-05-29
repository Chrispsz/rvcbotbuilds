/*
 * OTA Updater for Chrispsz/rvcbotbuilds
 * Smart update system — Instagram-focused changelog,
 * silent background check, 24h cooldown, version tracking.
 */

package app.morphe.extension.instagram.patches;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

import app.morphe.extension.crimera.PikoUtils;
import app.morphe.extension.shared.Utils;

public class OtaUpdater {

    private static final String GITHUB_REPO = "Chrispsz/rvcbotbuilds";
    private static final String GITHUB_API = "https://api.github.com/repos/" + GITHUB_REPO + "/releases/latest";
    private static final String USER_AGENT = "rvcbotbuilds-ota/2.0";

    // Shared preferences keys
    private static final String PREFS_NAME = "piko_ota";
    private static final String KEY_LAST_CHECK = "last_check_ms";
    private static final String KEY_LAST_TAG = "last_known_tag";
    private static final String KEY_SKIPPED_TAG = "skipped_tag";

    // 24h cooldown for auto-check
    private static final long CHECK_COOLDOWN_MS = 24 * 60 * 60 * 1000L;

    // ======== Public API ========

    /**
     * Manual check — always shows result dialog (success or "already up to date").
     */
    public static void checkForUpdates(Activity activity) {
        performCheck(activity, true);
    }

    /**
     * Silent auto-check — respects 24h cooldown, only notifies on new version.
     * Call this on app launch.
     */
    public static void autoCheck(Activity activity) {
        performCheck(activity, false);
    }

    // ======== Core logic ========

    private static void performCheck(Activity activity, boolean manual) {
        new Thread(() -> {
            try {
                // Cooldown check for auto mode
                if (!manual) {
                    SharedPreferences prefs = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
                    long lastCheck = prefs.getLong(KEY_LAST_CHECK, 0);
                    if (System.currentTimeMillis() - lastCheck < CHECK_COOLDOWN_MS) {
                        return; // Too soon, skip silently
                    }
                }

                String currentVersion = Utils.getAppVersionName();
                String[] releaseInfo = fetchLatestRelease();

                // Save check timestamp
                SharedPreferences prefs = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
                prefs.edit().putLong(KEY_LAST_CHECK, System.currentTimeMillis()).apply();

                if (releaseInfo == null) {
                    if (manual) {
                        showOnUi(activity, "Não foi possível verificar atualizações.\nVerifique sua conexão.");
                    }
                    return;
                }

                String latestTag = releaseInfo[0];
                String downloadUrl = releaseInfo[1];
                String changelog = releaseInfo[2];

                // Save latest known tag
                prefs.edit().putString(KEY_LAST_TAG, latestTag).apply();

                if (isNewerVersion(currentVersion, latestTag)) {
                    // User skipped this version?
                    if (!manual && latestTag.equals(prefs.getString(KEY_SKIPPED_TAG, ""))) {
                        return; // Don't re-notify for skipped version
                    }
                    String igChangelog = extractInstagramChangelog(changelog);
                    showUpdateDialog(activity, latestTag, igChangelog, downloadUrl, manual);
                } else if (manual) {
                    showOnUi(activity, "✅ Já está na versão mais recente: " + latestTag);
                }
            } catch (Exception e) {
                if (manual) {
                    showOnUi(activity, "Falha ao verificar: " + e.getMessage());
                }
            }
        }).start();
    }

    // ======== Smart changelog ========

    /**
     * Extract ONLY the Instagram section from the release notes.
     * Parses structured format:
     *   📸 Instagram — 🔨 Rebuilt
     *      Piko v1.x · Base 430.x
     *   ...
     *   ━━━
     *   📸 Instagram
     *   AMOLED · Download · ...
     */
    private static String extractInstagramChangelog(String raw) {
        if (raw == null || raw.isEmpty()) return "";

        String[] lines = raw.split("\\\\n|\n");
        StringBuilder igSection = new StringBuilder();
        boolean inIgBlock = false;
        boolean pastFirstBlock = false;

        // Separator that marks the detail sections
        boolean pastSeparator = false;

        for (String line : lines) {
            String trimmed = line.trim();
            if (trimmed.isEmpty()) continue;

            // Detect separator (━━━ or ---)
            if (trimmed.matches("[-━]{3,}")) {
                pastSeparator = true;
                inIgBlock = false;
                continue;
            }

            // First block: status lines (📸 Instagram — 🔨 Rebuilt)
            if (!pastSeparator) {
                if (trimmed.contains("📸") || trimmed.contains("Instagram")) {
                    inIgBlock = true;
                    // Clean: remove emoji prefix, keep content
                    String cleaned = trimmed
                            .replaceFirst("^[📸📺🎵]\\s*", "")
                            .replace("Instagram — ", "Instagram: ");
                    igSection.append(cleaned).append("\n");
                    continue;
                }
                // Continuation line (indented detail under Instagram)
                if (inIgBlock && (trimmed.startsWith("Piko") || trimmed.startsWith("Base") || trimmed.contains("Carried"))) {
                    igSection.append("  ").append(trimmed).append("\n");
                    inIgBlock = false;
                    continue;
                }
                // Hit YouTube/Music line — end of Instagram block
                if (trimmed.contains("📺") || trimmed.contains("🎵") || trimmed.contains("YouTube") || trimmed.contains("Music")) {
                    inIgBlock = false;
                    continue;
                }
            }

            // Second block: detail sections (📸 Instagram\n AMOLED · ...)
            if (pastSeparator) {
                if (trimmed.contains("📸") || trimmed.contains("Instagram")) {
                    inIgBlock = true;
                    // Skip the header "📸 Instagram" — it's redundant
                    continue;
                }
                if (inIgBlock) {
                    // End Instagram detail block when hitting YouTube/Music
                    if (trimmed.contains("📺") || trimmed.contains("🎵") ||
                        trimmed.contains("YouTube") || trimmed.contains("Music")) {
                        inIgBlock = false;
                        continue;
                    }
                    // Skip "🔧 Smart CI" section
                    if (trimmed.contains("🔧") || trimmed.contains("Smart CI")) {
                        inIgBlock = false;
                        continue;
                    }
                    // Skip bullet list items under Smart CI
                    if (trimmed.startsWith("•")) {
                        continue;
                    }
                    igSection.append(trimmed).append("\n");
                }
            }
        }

        String result = igSection.toString().trim();
        if (result.isEmpty()) {
            // Fallback: generic clean
            result = cleanFallback(raw);
        }

        if (result.length() > 350) {
            result = result.substring(0, 350).trim() + "…";
        }

        return result;
    }

    /**
     * Fallback: strip all markdown and return cleaned text (limited).
     */
    private static String cleanFallback(String raw) {
        String text = raw;
        text = text.replaceAll("(?m)^\\|.*\\|\\s*$", "");
        text = text.replaceAll("<[^>]+>", "");
        text = text.replaceAll("\\*{1,2}([^*]+)\\*{1,2}", "$1");
        text = text.replaceAll("\\[([^]]+)\\]\\([^)]+\\)", "$1");
        text = text.replaceAll("[-━]{3,}", "");
        text = text.replaceAll("\n{3,}", "\n\n");
        String[] lines = text.split("\n");
        StringBuilder sb = new StringBuilder();
        for (String line : lines) {
            String t = line.trim();
            if (!t.isEmpty()) sb.append(t).append("\n");
        }
        return sb.toString().trim();
    }

    // ======== GitHub API ========

    private static String[] fetchLatestRelease() {
        try {
            URL url = new URL(GITHUB_API);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("GET");
            conn.setRequestProperty("User-Agent", USER_AGENT);
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);

            if (conn.getResponseCode() != 200) return null;

            BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
            StringBuilder response = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
            reader.close();

            String json = response.toString();
            String tagName = extractJsonString(json, "tag_name");
            String body = extractJsonString(json, "body");
            String apkUrl = extractApkUrl(json);

            if (tagName != null && apkUrl != null) {
                return new String[]{tagName, apkUrl, body != null ? body : ""};
            }
        } catch (Exception e) {
            PikoUtils.logger(e);
        }
        return null;
    }

    private static String extractJsonString(String json, String key) {
        String searchKey = "\"" + key + "\"";
        int keyIndex = json.indexOf(searchKey);
        if (keyIndex == -1) return null;
        int colonIndex = json.indexOf(":", keyIndex);
        if (colonIndex == -1) return null;
        int valueStart = json.indexOf("\"", colonIndex);
        if (valueStart == -1) return null;
        int valueEnd = json.indexOf("\"", valueStart + 1);
        if (valueEnd == -1) return null;
        return json.substring(valueStart + 1, valueEnd);
    }

    private static String extractApkUrl(String json) {
        try {
            int assetsIndex = json.indexOf("\"assets\"");
            if (assetsIndex == -1) return null;
            String searchStr = "browser_download_url";
            int searchStart = assetsIndex;
            String fallback = null;
            while (true) {
                int urlKeyIndex = json.indexOf(searchStr, searchStart);
                if (urlKeyIndex == -1) break;
                int colonIndex = json.indexOf(":", urlKeyIndex);
                int valueStart = json.indexOf("\"", colonIndex);
                int valueEnd = json.indexOf("\"", valueStart + 1);
                if (valueStart == -1 || valueEnd == -1) break;
                String url = json.substring(valueStart + 1, valueEnd);
                if (url.endsWith(".apk")) {
                    if (url.contains("instagram")) return url;
                    if (fallback == null) fallback = url;
                }
                searchStart = valueEnd;
            }
            return fallback;
        } catch (Exception e) {
            PikoUtils.logger(e);
        }
        return null;
    }

    // ======== Version comparison ========

    private static boolean isNewerVersion(String currentVersion, String latestTag) {
        String current = currentVersion.replace("v", "").trim();
        String latest = latestTag.replace("v", "").trim();
        if (current.isEmpty() || latest.isEmpty()) return true;
        String[] currentParts = current.split("\\.");
        String[] latestParts = latest.split("\\.");
        int maxLen = Math.max(currentParts.length, latestParts.length);
        for (int i = 0; i < maxLen; i++) {
            int c = i < currentParts.length ? safeParseInt(currentParts[i]) : 0;
            int l = i < latestParts.length ? safeParseInt(latestParts[i]) : 0;
            if (l > c) return true;
            if (l < c) return false;
        }
        return false;
    }

    private static int safeParseInt(String s) {
        try {
            StringBuilder num = new StringBuilder();
            for (char c : s.toCharArray()) {
                if (Character.isDigit(c)) num.append(c);
                else break;
            }
            return num.length() > 0 ? Integer.parseInt(num.toString()) : 0;
        } catch (Exception e) { return 0; }
    }

    // ======== UI ========

    private static void showUpdateDialog(Activity activity, String version, String changelog, String downloadUrl, boolean manual) {
        new Handler(Looper.getMainLooper()).post(() -> {
            try {
                StringBuilder message = new StringBuilder();
                message.append("Nova versão: ").append(version);

                if (!changelog.isEmpty()) {
                    message.append("\n\n").append(changelog);
                }

                SharedPreferences prefs = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);

                new AlertDialog.Builder(activity)
                    .setTitle("⚡ Atualização disponível")
                    .setMessage(message.toString())
                    .setPositiveButton("Baixar", (dialog, which) -> {
                        prefs.edit().remove(KEY_SKIPPED_TAG).apply();
                        downloadApk(activity, downloadUrl, version);
                    })
                    .setNeutralButton("Depois", (dialog, which) -> {
                        // Remember user skipped this version
                        prefs.edit().putString(KEY_SKIPPED_TAG, version).apply();
                    })
                    .setNegativeButton("Ver no GitHub", (dialog, which) -> {
                        Intent browserIntent = new Intent(Intent.ACTION_VIEW,
                                Uri.parse("https://github.com/" + GITHUB_REPO + "/releases/latest"));
                        browserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        activity.startActivity(browserIntent);
                    })
                    .show();
            } catch (Exception e) {
                Toast.makeText(activity, "Atualização: " + version, Toast.LENGTH_LONG).show();
            }
        });
    }

    private static void downloadApk(Context context, String downloadUrl, String version) {
        try {
            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(downloadUrl));
            request.setTitle("Mod " + version);
            request.setDescription("Baixando atualização...");
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "rvcbotbuilds/instagram-" + version + ".apk");
            DownloadManager dm = (DownloadManager) context.getSystemService(Context.DOWNLOAD_SERVICE);
            long downloadId = dm.enqueue(request);
            Toast.makeText(context, "Baixando atualização... Verifique as notificações.", Toast.LENGTH_LONG).show();

            BroadcastReceiver receiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context ctx, Intent intent) {
                    long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1);
                    if (id == downloadId) {
                        try { context.unregisterReceiver(this); } catch (Exception ignored) {}
                        DownloadManager.Query query = new DownloadManager.Query();
                        query.setFilterById(downloadId);
                        Cursor cursor = dm.query(query);
                        if (cursor != null && cursor.moveToFirst()) {
                            int uriIndex = cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI);
                            if (uriIndex != -1) {
                                String localUri = cursor.getString(uriIndex);
                                promptInstall(context, localUri);
                            }
                            cursor.close();
                        }
                    }
                }
            };
            context.registerReceiver(receiver, new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE));
        } catch (Exception e) {
            try {
                Intent browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(downloadUrl));
                browserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(browserIntent);
            } catch (Exception ex) {
                Toast.makeText(context, "Falha no download. Abra o navegador.", Toast.LENGTH_LONG).show();
            }
        }
    }

    private static void promptInstall(Context context, String fileUri) {
        try {
            Intent installIntent = new Intent(Intent.ACTION_VIEW);
            installIntent.setDataAndType(Uri.parse(fileUri), "application/vnd.android.package-archive");
            installIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(installIntent);
        } catch (Exception e) {
            try {
                Intent openDownloads = new Intent(DownloadManager.ACTION_VIEW_DOWNLOADS);
                openDownloads.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(openDownloads);
            } catch (Exception ex2) {
                Toast.makeText(context, "APK em Downloads/rvcbotbuilds/", Toast.LENGTH_LONG).show();
            }
        }
    }

    private static void showOnUi(Activity activity, String message) {
        new Handler(Looper.getMainLooper()).post(() -> {
            try {
                new AlertDialog.Builder(activity)
                    .setTitle("Atualização")
                    .setMessage(message)
                    .setPositiveButton("OK", null)
                    .show();
            } catch (Exception e) {
                Toast.makeText(activity, message, Toast.LENGTH_LONG).show();
            }
        });
    }
}
