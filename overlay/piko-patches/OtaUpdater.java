/*
 * OTA Updater for Chrispsz/rvcbotbuilds
 * Checks GitHub releases for new mod APK versions
 * Downloads and triggers install — NO ROOT required
 */

package app.morphe.extension.instagram.patches;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.Cursor;
import android.net.Uri;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

import app.morphe.extension.crimera.PikoUtils;
import app.morphe.extension.shared.Utils;

public class OtaUpdater {

    private static final String GITHUB_REPO = "Chrispsz/rvcbotbuilds";
    private static final String GITHUB_API = "https://api.github.com/repos/" + GITHUB_REPO + "/releases/latest";
    private static final String USER_AGENT = "rvcbotbuilds-ota/1.0";

    /**
     * Check for updates from GitHub releases.
     */
    public static void checkForUpdates(Activity activity) {
        new Thread(() -> {
            try {
                String currentVersion = Utils.getAppVersionName();
                String[] releaseInfo = fetchLatestRelease();

                if (releaseInfo == null) {
                    showOnUi(activity, "Não foi possível verificar atualizações. Verifique sua conexão.");
                    return;
                }

                String latestTag = releaseInfo[0];
                String downloadUrl = releaseInfo[1];
                String changelog = releaseInfo[2];

                if (isNewerVersion(currentVersion, latestTag)) {
                    showUpdateDialog(activity, latestTag, changelog, downloadUrl);
                } else {
                    showOnUi(activity, "✅ Já está na versão mais recente: " + latestTag);
                }
            } catch (Exception e) {
                showOnUi(activity, "Falha ao verificar: " + e.getMessage());
            }
        }).start();
    }

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
                    // Prefer Instagram APK specifically (handles multi-APK releases)
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

    private static void showUpdateDialog(Activity activity, String version, String changelog, String downloadUrl) {
        new Handler(Looper.getMainLooper()).post(() -> {
            try {
                StringBuilder message = new StringBuilder();
                message.append("Nova versão: ").append(version);

                if (changelog != null && !changelog.isEmpty()) {
                    String clean = cleanChangelog(changelog);
                    if (!clean.isEmpty()) {
                        message.append("\n\n").append(clean);
                    }
                }

                new AlertDialog.Builder(activity)
                    .setTitle("⚡ Atualização disponível")
                    .setMessage(message.toString())
                    .setPositiveButton("Baixar", (dialog, which) -> downloadApk(activity, downloadUrl, version))
                    .setNegativeButton("Depois", null)
                    .show();
            } catch (Exception e) {
                Toast.makeText(activity, "Atualização: " + version, Toast.LENGTH_LONG).show();
            }
        });
    }

    /**
     * Strip markdown and clean changelog for display in AlertDialog.
     * Removes tables, HTML tags, horizontal rules, and excessive whitespace.
     */
    private static String cleanChangelog(String raw) {
        String text = raw;
        // Strip markdown table lines (|...|)
        text = text.replaceAll("(?m)^\\|.*\\|\\s*$", "");
        // Strip HTML tags
        text = text.replaceAll("<[^>]+>", "");
        // Strip markdown bold/italic
        text = text.replaceAll("\\*{1,2}([^*]+)\\*{1,2}", "$1");
        // Strip markdown links [text](url)
        text = text.replaceAll("\\[([^]]+)\\]\\([^)]+\\)", "$1");
        // Strip horizontal rules (--- or ━━━)
        text = text.replaceAll("[-━]{3,}", "");
        // Collapse 3+ blank lines into 2
        text = text.replaceAll("\n{3,}", "\n\n");
        // Trim each line
        String[] lines = text.split("\n");
        StringBuilder sb = new StringBuilder();
        for (String line : lines) {
            String trimmed = line.trim();
            if (!trimmed.isEmpty()) {
                sb.append(trimmed).append("\n");
            } else if (sb.length() > 0 && sb.charAt(sb.length() - 1) != '\n') {
                sb.append("\n");
            }
        }
        String result = sb.toString().trim();
        // Limit length
        if (result.length() > 400) {
            result = result.substring(0, 400).trim() + "…";
        }
        return result;
    }

    private static void downloadApk(Context context, String downloadUrl, String version) {
        try {
            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(downloadUrl));
            request.setTitle("Mod " + version);
            request.setDescription("Baixando atualização...");
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "rvcbotbuilds/instagram-morphe-" + version + ".apk");
            DownloadManager dm = (DownloadManager) context.getSystemService(Context.DOWNLOAD_SERVICE);
            long downloadId = dm.enqueue(request);
            Toast.makeText(context, "Baixando atualização... Verifique a barra de notificações.", Toast.LENGTH_LONG).show();

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
            // Fallback: open in browser
            try {
                Intent browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(downloadUrl));
                browserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(browserIntent);
            } catch (Exception ex) {
                Toast.makeText(context, "Falha no download. Abra o navegador manualmente.", Toast.LENGTH_LONG).show();
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
