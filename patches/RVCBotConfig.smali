.class public Lapp/morphe/extension/instagram/patches/RVCBotConfig;
.super Ljava/lang/Object;
.source "RVCBotConfig.java"


# static fields
.field private static final CONFIG_DIR:Ljava/lang/String; = "/mobileconfig"

.field private static final CONFIG_FILE:Ljava/lang/String; = "mc_overrides.json"

.field private static final OTA_URL:Ljava/lang/String; = "https://raw.githubusercontent.com/Chrispsz/rvcbotbuilds/main/module/mc_overrides.json"

.field private static final TAG:Ljava/lang/String; = "RVCBotConfig"


# direct methods
.method public constructor <init>()V
    .registers 1

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method

.method public static init()V
    .registers 4

    :try_start_0
    # Get app context
    invoke-static {}, Lapp/morphe/extension/shared/Utils;->getContext()Landroid/content/Context;

    move-result-object v0

    if-eqz v0, :cond_return

    # Get files dir
    invoke-virtual {v0}, Landroid/content/Context;->getFilesDir()Ljava/io/File;

    move-result-object v1

    # Build config file path: filesDir/mobileconfig/mc_overrides.json
    new-instance v2, Ljava/io/File;

    new-instance v3, Ljava/lang/StringBuilder;

    invoke-direct {v3}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v1}, Ljava/io/File;->getAbsolutePath()Ljava/lang/String;

    move-result-object v1

    invoke-virtual {v3, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v1, "/mobileconfig"

    invoke-virtual {v3, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v3}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v1

    const-string v3, "mc_overrides.json"

    invoke-direct {v2, v1, v3}, Ljava/io/File;-><init>(Ljava/lang/String;Ljava/lang/String;)V

    # Check if config file already exists
    invoke-virtual {v2}, Ljava/io/File;->exists()Z

    move-result v1

    if-nez v1, :cond_ota

    # File doesn't exist - try to copy from assets
    invoke-static {v0, v2}, Lapp/morphe/extension/instagram/patches/RVCBotConfig;->copyFromAssets(Landroid/content/Context;Ljava/io/File;)Z

    move-result v1

    if-eqz v1, :cond_ota

    # Log success
    const-string v1, "RVCBotConfig: Copied mc_overrides.json from APK assets"

    invoke-static {v1}, Lapp/morphe/extension/crimera/PikoUtils;->logger(Ljava/lang/Object;)V

    :cond_ota
    # Start OTA check in background thread
    new-instance v1, Ljava/lang/Thread;

    new-instance v2, Lapp/morphe/extension/instagram/patches/RVCBotConfig$1;

    invoke-direct {v2, v0}, Lapp/morphe/extension/instagram/patches/RVCBotConfig$1;-><init>(Landroid/content/Context;)V

    invoke-direct {v1, v2}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V

    invoke-virtual {v1}, Ljava/lang/Thread;->start()V
    :try_end_all
    .catch Ljava/lang/Exception; {:try_start_0 .. :try_end_all} :catch_exception

    goto :cond_return

    :catch_exception
    move-exception v0

    const-string v1, "RVCBotConfig: init failed"

    invoke-static {v1}, Lapp/morphe/extension/crimera/PikoUtils;->logger(Ljava/lang/Object;)V

    :cond_return
    return-void
.end method

.method private static copyFromAssets(Landroid/content/Context;Ljava/io/File;)Z
    .registers 6

    const/4 v0, 0x0

    :try_start_0
    # Get AssetManager
    invoke-virtual {p0}, Landroid/content/Context;->getAssets()Landroid/content/res/AssetManager;

    move-result-object v1

    const-string v2, "mc_overrides.json"

    invoke-virtual {v1, v2}, Landroid/content/res/AssetManager;->open(Ljava/lang/String;)Ljava/io/InputStream;

    move-result-object v1
    :try_end_a
    .catch Ljava/lang/Exception; {:try_start_0 .. :try_end_a} :catch_open

    if-nez v1, :cond_create

    return v0

    :cond_create
    # Create parent directory
    :try_start_b
    invoke-virtual {p1}, Ljava/io/File;->getParentFile()Ljava/io/File;

    move-result-object v2

    if-eqz v2, :cond_skip_mkdirs

    invoke-virtual {v2}, Ljava/io/File;->mkdirs()Z

    :cond_skip_mkdirs
    # Open output stream
    new-instance v2, Ljava/io/FileOutputStream;

    invoke-direct {v2, p1}, Ljava/io/FileOutputStream;-><init>(Ljava/io/File;)V

    # Copy buffer
    const/16 v3, 0x1000

    new-array v3, v3, [B

    :loop_start
    invoke-virtual {v1, v3}, Ljava/io/InputStream;->read([B)I

    move-result p0

    const/4 p1, -0x1

    if-eq p0, p1, :cond_done

    const/4 p1, 0x0

    invoke-virtual {v2, v3, p1, p0}, Ljava/io/FileOutputStream;->write([BII)V

    goto :loop_start

    :cond_done
    invoke-virtual {v2}, Ljava/io/FileOutputStream;->close()V

    invoke-virtual {v1}, Ljava/io/InputStream;->close()V
    :try_end_done
    .catch Ljava/lang/Exception; {:try_start_b .. :try_end_done} :catch_copy

    const/4 v0, 0x1

    return v0

    :catch_open
    return v0

    :catch_copy
    move-exception p0

    const-string p1, "RVCBotConfig: copyFromAssets failed"

    invoke-static {p1}, Lapp/morphe/extension/crimera/PikoUtils;->logger(Ljava/lang/Object;)V

    return v0
.end method

.method public static checkOtaUpdate(Landroid/content/Context;)V
    .registers 8

    :try_start_0
    # Build URL
    new-instance v0, Ljava/net/URL;

    const-string v1, "https://raw.githubusercontent.com/Chrispsz/rvcbotbuilds/main/module/mc_overrides.json"

    invoke-direct {v0, v1}, Ljava/net/URL;-><init>(Ljava/lang/String;)V

    # Open connection
    invoke-virtual {v0}, Ljava/net/URL;->openConnection()Ljava/net/URLConnection;

    move-result-object v0

    check-cast v0, Ljava/net/HttpURLConnection;

    # Set timeouts (5s connect, 10s read)
    const/16 v1, 0x1388

    invoke-virtual {v0, v1}, Ljava/net/HttpURLConnection;->setConnectTimeout(I)V

    const/16 v1, 0x2710

    invoke-virtual {v0, v1}, Ljava/net/HttpURLConnection;->setReadTimeout(I)V

    const-string v1, "GET"

    invoke-virtual {v0, v1}, Ljava/net/HttpURLConnection;->setRequestMethod(Ljava/lang/String;)V

    # Get response
    invoke-virtual {v0}, Ljava/net/HttpURLConnection;->getResponseCode()I

    move-result v1

    const/16 v2, 0xc8

    if-ne v1, v2, :cond_cleanup

    # Read input stream
    invoke-virtual {v0}, Ljava/net/HttpURLConnection;->getInputStream()Ljava/io/InputStream;

    move-result-object v1

    # Build temp file path
    invoke-virtual {p0}, Landroid/content/Context;->getFilesDir()Ljava/io/File;

    move-result-object v2

    new-instance v3, Ljava/io/File;

    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v2}, Ljava/io/File;->getAbsolutePath()Ljava/lang/String;

    move-result-object v2

    invoke-virtual {v4, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v2, "/mobileconfig"

    invoke-virtual {v4, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v2

    const-string v4, "mc_overrides.json.tmp"

    invoke-direct {v3, v2, v4}, Ljava/io/File;-><init>(Ljava/lang/String;Ljava/lang/String;)V

    # Write to temp file
    new-instance v4, Ljava/io/FileOutputStream;

    invoke-direct {v4, v3}, Ljava/io/FileOutputStream;-><init>(Ljava/io/File;)V

    const/16 v5, 0x1000

    new-array v5, v5, [B

    :loop_start
    invoke-virtual {v1, v5}, Ljava/io/InputStream;->read([B)I

    move-result v6

    const/4 p0, -0x1

    if-eq v6, p0, :cond_write_done

    const/4 p0, 0x0

    invoke-virtual {v4, v5, p0, v6}, Ljava/io/FileOutputStream;->write([BII)V

    goto :loop_start

    :cond_write_done
    invoke-virtual {v4}, Ljava/io/FileOutputStream;->close()V

    invoke-virtual {v1}, Ljava/io/InputStream;->close()V

    # Sanity check: temp file should be > 100 bytes
    invoke-virtual {v3}, Ljava/io/File;->length()J

    move-result-wide v4

    const-wide/16 v6, 0x64

    cmp-long p0, v4, v6

    if-lez p0, :cond_delete_tmp

    # Build target file
    new-instance p0, Ljava/io/File;

    const-string v1, "mc_overrides.json"

    invoke-direct {p0, v2, v1}, Ljava/io/File;-><init>(Ljava/lang/String;Ljava/lang/String;)V

    # Delete old file and rename temp
    invoke-virtual {p0}, Ljava/io/File;->delete()Z

    invoke-virtual {v3, p0}, Ljava/io/File;->renameTo(Ljava/io/File;)Z

    move-result p0

    if-eqz p0, :cond_delete_tmp

    const-string p0, "RVCBotConfig: OTA update applied successfully"

    invoke-static {p0}, Lapp/morphe/extension/crimera/PikoUtils;->logger(Ljava/lang/Object;)V

    goto :cond_cleanup

    :cond_delete_tmp
    invoke-virtual {v3}, Ljava/io/File;->delete()Z

    :cond_cleanup
    invoke-virtual {v0}, Ljava/net/HttpURLConnection;->disconnect()V
    :try_end_all
    .catch Ljava/lang/Exception; {:try_start_0 .. :try_end_all} :catch_exception

    goto :cond_return

    :catch_exception
    move-exception p0

    const-string v0, "RVCBotConfig: OTA check failed (expected if offline)"

    invoke-static {v0}, Lapp/morphe/extension/crimera/PikoUtils;->logger(Ljava/lang/Object;)V

    :cond_return
    return-void
.end method
