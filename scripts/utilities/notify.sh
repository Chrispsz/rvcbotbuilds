#!/usr/bin/env bash
# ============================================
# notify.sh — Telegram notification for CI results
# ============================================
# Sends a message to Telegram if TELEGRAM_BOT_TOKEN and
# TELEGRAM_CHAT_ID are set. Gracefully no-ops (with a log line)
# if the secrets are missing, so the job never fails because of
# notification.
#
# Env vars (provided by ci.yml):
#   TELEGRAM_BOT_TOKEN  — bot token from @BotFather
#   TELEGRAM_CHAT_ID    — chat/channel ID to send to
#   REPO                — github.repository (owner/name)
#   RUN_ID              — github.run_id (for deep link)
#   PREFLIGHT, SYNC, BUILD, RELEASE, META, CLEANUP — job results
#
# Exit codes:
#   0 — always (notification is best-effort, never blocks CI)
# ============================================
set -uo pipefail

# ---- Job results (default to "skipped" if unset) ----
PREFLIGHT="${PREFLIGHT:-skipped}"
SYNC="${SYNC:-skipped}"
BUILD="${BUILD:-skipped}"
RELEASE="${RELEASE:-skipped}"
META="${META:-skipped}"
CLEANUP="${CLEANUP:-skipped}"

# ---- Determine overall status ----
overall="success"
failed_jobs=""
for pair in "Preflight:$PREFLIGHT" "Sync:$SYNC" "Build:$BUILD" "Release:$RELEASE" "Meta:$META" "Cleanup:$CLEANUP"; do
  name="${pair%%:*}"
  result="${pair##*:}"
  if [ "$result" = "failure" ]; then
    overall="failure"
    failed_jobs="${failed_jobs}✗ ${name} FAILED\n"
  fi
done

# If everything succeeded (or was skipped), only notify on failure to avoid spam.
# Override: set NOTIFY_ON_SUCCESS=true to always notify.
if [ "$overall" = "success" ] && [ "${NOTIFY_ON_SUCCESS:-false}" != "true" ]; then
  echo "[notify] All jobs succeeded/skipped — no notification sent (set NOTIFY_ON_SUCCESS=true to override)"
  exit 0
fi

# ---- Check Telegram secrets ----
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "::warning::[notify] TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set — cannot send notification"
  echo "[notify] To enable: create a bot via @BotFather, get chat ID via @userinfobot, then add both as repo secrets."
  exit 0
fi

# ---- Build message ----
if [ "$overall" = "failure" ]; then
  emoji="🔴"
  title="CI Build FAILED"
else
  emoji="🟢"
  title="CI Build Succeeded"
fi

RUN_URL="https://github.com/${REPO}/actions/runs/${RUN_ID}"

# Escape text for Telegram MarkdownV2 (escape these: _ * [ ] ( ) ~ ` > # + - = | { } . !)
escape_md() {
  sed 's/[_*\[\]()~`>#+\-=|{}.!]/\\&/g' <<< "$1"
}

MESSAGE="${emoji} *${title}*
Repo: \`${REPO}\`
Run: [#${RUN_ID}](${RUN_URL})

*Job results:*
"

for pair in "Preflight:$PREFLIGHT" "Sync upstream:$SYNC" "Build:$BUILD" "Release:$RELEASE" "Update meta:$META" "Cleanup:$CLEANUP"; do
  name="${pair%%:*}"
  result="${pair##*:}"
  case "$result" in
    success)  mark="✅" ;;
    failure)  mark="❌" ;;
    skipped)  mark="⏭️" ;;
    cancelled) mark="🚫" ;;
    *)        mark="❓" ;;
  esac
  MESSAGE="${MESSAGE}${mark} ${name}: ${result}
"
done

if [ -n "$failed_jobs" ]; then
  MESSAGE="${MESSAGE}
*Failed:*
${failed_jobs}"
fi

MESSAGE="${MESSAGE}
[View run](${RUN_URL})"

# ---- Send via Telegram Bot API ----
# Use Python to handle JSON encoding safely (avoid shell quoting hell)
python3 - "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_CHAT_ID" "$MESSAGE" << 'PYEOF'
import json
import sys
import urllib.request
import urllib.error

token, chat_id, text = sys.argv[1], sys.argv[2], sys.argv[3]

url = f"https://api.telegram.org/bot{token}/sendMessage"
payload = {
    "chat_id": chat_id,
    "text": text,
    "parse_mode": "MarkdownV2",
    "disable_web_page_preview": True,
}
data = json.dumps(payload).encode("utf-8")
req = urllib.request.Request(
    url,
    data=data,
    headers={"Content-Type": "application/json", "User-Agent": "rvcbotbuilds-ci"},
)
try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        body = resp.read().decode("utf-8", "replace")
        if resp.status == 200:
            print("[notify] Telegram message sent successfully")
            sys.exit(0)
        else:
            print(f"[notify] Telegram API returned HTTP {resp.status}: {body[:300]}", file=sys.stderr)
            sys.exit(0)  # never fail the job
except urllib.error.URLError as e:
    print(f"[notify] Network error sending to Telegram: {e}", file=sys.stderr)
    sys.exit(0)  # never fail the job
except Exception as e:
    print(f"[notify] Unexpected error: {e}", file=sys.stderr)
    sys.exit(0)  # never fail the job
PYEOF

exit 0
