/*
 * OTA Updater for Chrispsz/rvcbotbuilds
 * v3.0 — Build-number aware, no memory leaks, Instagram-only changelog.
 *
 * Version format: v2025.05.29-1  (date-buildnum)
 * Same-day rebuilds increment the build number so OTA can detect them.
 * Installed tag is stored in SharedPreferences for accurate comparison.
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
    private static final String USER_AGENT = "rvcbotbuilds-ota/3.0";

    // SharedPreferences keys
    private static final String PREFS_NAME = "piko_ota";
    private static final String KEY_LAST_CHECK = "last_check_ms";
    private static final String KEY_INSTALLED_TAG = "installed_tag";
    private static final String KEY_SKIPPED_TAG = "skipped_tag";

    // 24h cooldown for auto-check
    private static final long CHECK_COOLDOWN_MS = 24 * 60 * 60 * 1000L;

    // Timeout for download completion receiver (5 minutes)
    private static final long DOWNLOAD_TIMEOUT_MS = 5 * 60 * 1000L;

    // Track active download receiver to prevent leaks
    private static BroadcastReceiver activeReceiver = null;
    private static long activeDownloadId = -1;
    private static Handler timeoutHandler = new Handler(Looper.getMainLooper());

    // Timeout runnable reference for targeted cancellation
    private static Runnable timeoutRunnable = null;

    // ======== Public API ========

    /**
     * Manual check — always shows result dialog.
     */
    public static void checkForUpdates(Activity activity) {
        performCheck(activity, true);
    }

    /**
     * Silent auto-check — 24h cooldown, only notifies on new version.
     */
    public static void autoCheck(Activity activity) {
        performCheck(activity, false);
    }

    // ======== Core logic ========

    private static void performCheck(Activity activity, boolean manual) {
        new Thread(() -> {
            try {
                SharedPreferences prefs = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);

                // Cooldown for auto mode
                if (!manual) {
                    long lastCheck = prefs.getLong(KEY_LAST_CHECK, 0);
                    if (System.currentTimeMillis() - lastCheck < CHECK_COOLDOWN_MS) {
                        return;
                    }
                }

                String[] releaseInfo = fetchLatestRelease();

                // Save check timestamp
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

                String installedTag = prefs.getString(KEY_INSTALLED_TAG, "");
                int comparison = compareTags(installedTag, latestTag);

                // comparison > 0 → latest is newer
                // comparison == 0 → same version
                // comparison < 0 → installed is newer (shouldn't happen)

                if (comparison > 0) {
                    // User skipped this specific tag?
                    if (!manual && latestTag.equals(prefs.getString(KEY_SKIPPED_TAG, ""))) {
                        return;
                    }
                    String igChangelog = extractInstagramChangelog(changelog);
                    showUpdateDialog(activity, installedTag, latestTag, igChangelog, downloadUrl);
                } else if (comparison == 0) {
                    if (manual) {
                        showOnUi(activity, "✅ Já está na versão mais recente: " + latestTag);
                    }
                } else {
                    // Installed is "newer" than latest — means our tag tracking is stale
                    // Update stored tag to latest
                    prefs.edit().putString(KEY_INSTALLED_TAG, latestTag).apply();
                    if (manual) {
                        showOnUi(activity, "✅ Já está na versão mais recente: " + latestTag);
                    }
                }
            } catch (Exception e) {
                if (manual) {
                    showOnUi(activity, "Falha ao verificar: " + e.getMessage());
                }
            }
        }).start();
    }

    // ======== Version comparison ========

    /**
     * Compare two release tags. Format: vYYYY.MM.DD-N or vYYYY.MM.DD
     * Returns: >0 if b is newer, 0 if equal, <0 if a is newer.
     */
    private static int compareTags(String a, String b) {
        if (a == null || a.isEmpty()) return 1; // No installed tag → treat as outdated
        if (b == null || b.isEmpty()) return -1;

        // Strip 'v' prefix
        String cleanA = a.replace("v", "").trim();
        String cleanB = b.replace("v", "").trim();

        // Split date and build number: "2025.05.29-2" → date="2025.05.29", build=2
        String[] partsA = cleanA.split("-", 2);
        String[] partsB = cleanB.split("-", 2);

        String dateA = partsA[0];
        String dateB = partsB[0];
        int buildA = partsA.length > 1 ? safeParseInt(partsA[1]) : 0;
        int buildB = partsB.length > 1 ? safeParseInt(partsB[1]) : 0;

        // Compare date parts
        String[] datePartsA = dateA.split("\\.");
        String[] datePartsB = dateB.split("\\.");
        int maxLen = Math.max(datePartsA.length, datePartsB.length);
        for (int i = 0; i < maxLen; i++) {
            int da = i < datePartsA.length ? safeParseInt(datePartsA[i]) : 0;
            int db = i < datePartsB.length ? safeParseInt(datePartsB[i]) : 0;
            if (db != da) return db - da;
        }

        // Same date → compare build number
        return buildB - buildA;
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

    /**
     * Format tag for display: "v2025.05.29-2" → "29/05/2025 build 2"
     * "v2025.05.29" → "29/05/2025"
     */
    private static String formatTagDisplay(String tag) {
        if (tag == null || tag.isEmpty()) return "—";
        String clean = tag.replace("v", "");
        String[] parts = clean.split("-", 2);
        String date = parts[0];
        String[] d = date.split("\\.");
        String display;
        if (d.length >= 3) {
            display = d[2] + "/" + d[1] + "/" + d[0];
        } else {
            display = date;
        }
        if (parts.length > 1 && !parts[1].equals("0")) {
            display += " build " + parts[1];
        }
        return display;
    }

    // ======== Smart changelog ========

    private static String extractInstagramChangelog(String raw) {
        if (raw == null || raw.isEmpty()) return "";

        String[] lines = raw.split("\\\\n|\n");
        StringBuilder igSection = new StringBuilder();
        boolean inIgBlock = false;
        boolean pastSeparator = false;

        for (String line : lines) {
            String trimmed = line.trim();
            if (trimmed.isEmpty()) continue;

            if (trimmed.matches("[-━]{3,}")) {
                pastSeparator = true;
                inIgBlock = false;
                continue;
            }

            if (!pastSeparator) {
                if (trimmed.contains("📸") || trimmed.contains("Instagram")) {
                    inIgBlock = true;
                    String cleaned = trimmed
                            .replaceFirst("^[📸📺🎵]\\s*", "")
                            .replace("Instagram — ", "Instagram: ");
                    igSection.append(cleaned).append("\n");
                    continue;
                }
                if (inIgBlock && (trimmed.startsWith("Piko") || trimmed.startsWith("Base") || trimmed.contains("Carried"))) {
                    igSection.append("  ").append(trimmed).append("\n");
                    inIgBlock = false;
                    continue;
                }
                if (trimmed.contains("📺") || trimmed.contains("🎵") || trimmed.contains("YouTube") || trimmed.contains("Music")) {
                    inIgBlock = false;
                    continue;
                }
            }

            if (pastSeparator) {
                if (trimmed.contains("📸") || trimmed.contains("Instagram")) {
                    inIgBlock = true;
                    continue;
                }
                if (inIgBlock) {
                    if (trimmed.contains("📺") || trimmed.contains("🎵") ||
                        trimmed.contains("YouTube") || trimmed.contains("Music")) {
                        inIgBlock = false;
                        continue;
                    }
                    if (trimmed.contains("🔧") || trimmed.contains("Smart CI")) {
                        inIgBlock = false;
                        continue;
                    }
                    if (trimmed.startsWith("•")) continue;
                    igSection.append(trimmed).append("\n");
                }
            }
        }

        String result = igSection.toString().trim();
        if (result.isEmpty()) {
            result = cleanFallback(raw);
        }
        if (result.length() > 350) {
            result = result.substring(0, 350).trim() + "…";
        }
        return result;
    }

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
        HttpURLConnection conn = null;
        try {
            URL url = new URL(GITHUB_API);
            conn = (HttpURLConnection) url.openConnection();
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
        } finally {
            if (conn != null) {
                try { conn.disconnect(); } catch (Exception ignored) {}
            }
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

    // ======== UI ========

    private static void showUpdateDialog(Activity activity, String installedTag, String latestTag, String changelog, String downloadUrl) {
        new Handler(Looper.getMainLooper()).post(() -> {
            try {
                StringBuilder message = new StringBuilder();

                // Clear version comparison
                String installedDisplay = formatTagDisplay(installedTag);
                String latestDisplay = formatTagDisplay(latestTag);
                message.append("Instalada: ").append(installedDisplay);
                message.append("\nDisponível: ").append(latestDisplay);

                if (!changelog.isEmpty()) {
                    message.append("\n\n").append(changelog);
                }

                SharedPreferences prefs = activity.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);

                new AlertDialog.Builder(activity)
                    .setTitle("⚡ Atualização disponível")
                    .setMessage(message.toString())
                    .setPositiveButton("Baixar", (dialog, which) -> {
                        prefs.edit()
                            .remove(KEY_SKIPPED_TAG)
                            .putString(KEY_INSTALLED_TAG, latestTag)
                            .apply();
                        downloadApk(activity, downloadUrl, latestTag);
                    })
                    .setNeutralButton("Depois", (dialog, which) -> {
                        prefs.edit().putString(KEY_SKIPPED_TAG, latestTag).apply();
                    })
                    .setNegativeButton("GitHub", (dialog, which) -> {
                        Intent browserIntent = new Intent(Intent.ACTION_VIEW,
                                Uri.parse("https://github.com/" + GITHUB_REPO + "/releases/latest"));
                        browserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        activity.startActivity(browserIntent);
                    })
                    .show();
            } catch (Exception e) {
                Toast.makeText(activity, "Atualização: " + latestTag, Toast.LENGTH_LONG).show();
            }
        });
    }

    // ======== Download (leak-safe) ========

    private static void downloadApk(Context context, String downloadUrl, String version) {
        try {
            // Unregister any previous receiver first (prevents leak)
            unregisterReceiverSafe(context);

            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(downloadUrl));
            request.setTitle("Mod " + version);
            request.setDescription("Baixando atualização...");
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS,
                    "rvcbotbuilds/instagram-" + version + ".apk");

            DownloadManager dm = (DownloadManager) context.getSystemService(Context.DOWNLOAD_SERVICE);
            activeDownloadId = dm.enqueue(request);
            Toast.makeText(context, "Baixando atualização... Verifique as notificações.", Toast.LENGTH_LONG).show();

            // Register receiver with timeout
            activeReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context ctx, Intent intent) {
                    long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1);
                    if (id == activeDownloadId) {
                        // Unregister immediately — no leak
                        unregisterReceiverSafe(ctx);
                        cancelTimeout();

                        DownloadManager.Query query = new DownloadManager.Query();
                        query.setFilterById(activeDownloadId);
                        Cursor cursor = dm.query(query);
                        if (cursor != null && cursor.moveToFirst()) {
                            int uriIndex = cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI);
                            if (uriIndex != -1) {
                                String localUri = cursor.getString(uriIndex);
                                promptInstall(ctx, localUri);
                            }
                            cursor.close();
                        }
                        activeDownloadId = -1;
                    }
                }
            };
            // Android 13+ (API 33) requires RECEIVER_EXPORTED/RECEIVER_NOT_EXPORTED flag
            try {
                context.registerReceiver(activeReceiver,
                        new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE),
                        Context.RECEIVER_NOT_EXPORTED, null);
            } catch (NoSuchMethodError e) {
                // API < 33: registerReceiver doesn't accept flags
                context.registerReceiver(activeReceiver,
                        new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE));
            }

            // Safety timeout — unregister after 5 minutes to prevent leak
            timeoutRunnable = () -> {
                unregisterReceiverSafe(context);
                activeDownloadId = -1;
            };
            timeoutHandler.postDelayed(timeoutRunnable, DOWNLOAD_TIMEOUT_MS);

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

    private static void unregisterReceiverSafe(Context context) {
        if (activeReceiver != null) {
            try {
                context.unregisterReceiver(activeReceiver);
            } catch (Exception ignored) {}
            activeReceiver = null;
        }
    }

    private static void cancelTimeout() {
        if (timeoutRunnable != null) {
            timeoutHandler.removeCallbacks(timeoutRunnable);
            timeoutRunnable = null;
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
