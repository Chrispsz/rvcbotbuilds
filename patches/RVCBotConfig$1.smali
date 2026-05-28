.class Lapp/morphe/extension/instagram/patches/RVCBotConfig$1;
.super Ljava/lang/Object;
.source "RVCBotConfig.java"

# interfaces
.implements Ljava/lang/Runnable;


# instance fields
.field final synthetic val$context:Landroid/content/Context;


# direct methods
.method constructor <init>(Landroid/content/Context;)V
    .registers 2

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lapp/morphe/extension/instagram/patches/RVCBotConfig$1;->val$context:Landroid/content/Context;

    return-void
.end method


# virtual methods
.method public run()V
    .registers 2

    :try_start_0
    # Sleep 5 seconds to let app fully initialize
    const-wide/16 v0, 0x1388

    invoke-static {v0, v1}, Ljava/lang/Thread;->sleep(J)V
    :try_end_5
    .catch Ljava/lang/InterruptedException; {:try_start_0 .. :try_end_5} :catch_interrupt

    goto :cond_check

    :catch_interrupt
    return-void

    :cond_check
    iget-object v0, p0, Lapp/morphe/extension/instagram/patches/RVCBotConfig$1;->val$context:Landroid/content/Context;

    invoke-static {v0}, Lapp/morphe/extension/instagram/patches/RVCBotConfig;->checkOtaUpdate(Landroid/content/Context;)V

    return-void
.end method
