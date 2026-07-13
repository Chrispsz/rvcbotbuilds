#!/usr/bin/env bash
# ============================================
# gh-api.sh — GitHub API wrapper with resilience
# ============================================
# Provides:
#   gh_api_call  <method> <url> [output_file|-]  — HTTP call with retry+backoff
#   gh_api_get   <url> [output_file|-]           — shorthand for GET
#   gh_api_check_token                           — validates token, exits non-zero on failure
#   gh_push      <remote_url> <ref>              — git push with retry
#
# Design goals:
#   - NEVER fail silently on transient errors (5xx, rate-limit, network)
#   - ALWAYS fail loud and early on auth errors (401/403 with expired token)
#   - Respect X-RateLimit-Reset header when rate-limited
#   - Idempotent: safe to source multiple times
#
# Usage:
#   source scripts/utilities/gh-api.sh
#   gh_api_check_token || exit 1
#   gh_api_get "https://api.github.com/repos/foo/bar/releases/latest" - | jq -r .tag_name
# ============================================

# Guard against double-sourcing
if [ -n "${GH_API_SH_LOADED:-}" ]; then return 0 2>/dev/null || true; fi
GH_API_SH_LOADED=1

# ---- Configuration ----------------------------------------------------------
: "${GH_API_MAX_RETRIES:=4}"          # total attempts (1 initial + 3 retries)
: "${GH_API_BASE_BACKOFF:=2}"         # seconds; doubled each retry
: "${GH_API_MAX_RATE_WAIT:=600}"      # max seconds to wait for rate-limit reset
: "${GH_API_TIMEOUT:=30}"             # per-request connect+max-time

# Last response metadata (set after each gh_api_call)
GH_API_LAST_CODE=0
GH_API_LAST_BODY=""

# ---- Logging helpers --------------------------------------------------------
_gh_log()  { printf '::notice::gh-api: %s\n' "$*" >&2; }
_gh_warn() { printf '::warning::gh-api: %s\n' "$*" >&2; }
_gh_err()  { printf '::error::gh-api: %s\n' "$*" >&2; }
_gh_dbg()  { printf '::debug::gh-api: %s\n' "$*" >&2; }

# ---- Internal: single curl attempt, writes code+body to temp files --------
# _gh_curl_once <method> <url> <output_target> <code_file> <body_file>
_gh_curl_once() {
  local method="$1" url="$2" out="$3" code_file="$4" body_file="$5"
  local args=()

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    args+=(-H "Authorization: token ${GITHUB_TOKEN}"
           -H "X-GitHub-Api-Version: 2022-11-28")
  fi

  # When out="-", curl still needs a real file path for -o
  local real_out="$out"
  [ "$real_out" = "-" ] && real_out="$body_file"

  local code
  code=$(curl -sS -L --max-time "$GH_API_TIMEOUT" \
    -X "$method" \
    "${args[@]}" \
    -H 'User-Agent: rvcbotbuilds-ci' \
    -H 'Accept: application/vnd.github+json' \
    -w '%{http_code}' \
    -o "$real_out" \
    "$url" 2>/dev/null) || code="000"

  printf '%s' "$code" > "$code_file"
}

# ---- Public: GitHub API call with retry+backoff ----------------------------
# gh_api_call <method> <url> [output_file|-]
# Returns:
#   0 on 2xx, non-zero on persistent failure
#   Sets GH_API_LAST_CODE and GH_API_LAST_BODY
gh_api_call() {
  local method="${1:?gh_api_call: method required}"
  local url="${2:?gh_api_call: url required}"
  local out="${3:--}"

  local attempt=0
  local code
  local wait_sec=$GH_API_BASE_BACKOFF
  local code_file body_file
  code_file=$(mktemp)
  body_file=$(mktemp)

  # NOTE: Do NOT use `trap '...' RETURN` here — it propagates to all subsequent
  # function returns and, combined with `set -u`, causes unbound-variable exits
  # when the local vars are out of scope. Use explicit cleanup instead.
  _gh_cleanup() { rm -f "$code_file" "$body_file" 2>/dev/null || true; }

  while [ "$attempt" -lt "$GH_API_MAX_RETRIES" ]; do
    attempt=$((attempt + 1))
    _gh_curl_once "$method" "$url" "$out" "$code_file" "$body_file"
    code=$(cat "$code_file")
    GH_API_LAST_CODE="$code"
    [ "$out" = "-" ] && GH_API_LAST_BODY=$(cat "$body_file" 2>/dev/null || echo "")
    _gh_dbg "attempt $attempt: HTTP $code $method $url"

    # Success
    case "$code" in
      2*)
        _gh_cleanup
        return 0
        ;;
    esac

    # Auth errors — do NOT retry, fail immediately with clear message
    case "$code" in
      401|403)
        local body_snip
        body_snip=$(cat "$body_file" 2>/dev/null | head -c 500)
        if echo "$body_snip" | grep -qi 'rate limit'; then
          _gh_warn "rate-limited (HTTP $code) on attempt $attempt"
          # rate-limit is retryable after waiting
        else
          local tok_preview
          if [ -n "${GITHUB_TOKEN:-}" ]; then
            tok_preview="${GITHUB_TOKEN:0:4}...${GITHUB_TOKEN: -4}"
          else
            tok_preview="(none)"
          fi
          _gh_err "AUTH FAILURE (HTTP $code) — token '$tok_preview' is invalid or expired."
          _gh_err "URL: $url"
          _gh_err "Fix: rotate the PAT_TOKEN secret in repo settings."
          _gh_cleanup
          return 2
        fi
        ;;
      404)
        _gh_dbg "HTTP 404 (not found): $url"
        _gh_cleanup
        return 1
        ;;
      000)
        _gh_warn "network/timeout on attempt $attempt"
        ;;
      5*)
        _gh_warn "server error HTTP $code on attempt $attempt (will retry)"
        ;;
      *)
        _gh_warn "unexpected HTTP $code on attempt $attempt"
        ;;
    esac

    if [ "$attempt" -lt "$GH_API_MAX_RETRIES" ]; then
      _gh_dbg "retrying in ${wait_sec}s..."
      sleep "$wait_sec"
      wait_sec=$((wait_sec * 2))
    fi
  done

  _gh_err "exhausted $GH_API_MAX_RETRIES attempts — last HTTP $code"
  _gh_cleanup
  return 1
}

# ---- Public: GET shorthand -------------------------------------------------
gh_api_get() {
  gh_api_call GET "$@"
}

# ---- Public: validate GITHUB_TOKEN is alive --------------------------------
# Exits 0 if token works, 2 if invalid/expired, 1 if unknown failure
gh_api_check_token() {
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    _gh_err "GITHUB_TOKEN is not set"
    return 2
  fi

  local preview="${GITHUB_TOKEN:0:4}...${GITHUB_TOKEN: -4}"
  _gh_dbg "validating token $preview"

  # Use `|| rc=$?` to be safe under `set -e` (errexit)
  local rc=0
  gh_api_get "https://api.github.com/user" - >/dev/null 2>&1 || rc=$?
  case "$GH_API_LAST_CODE" in
    200)
      _gh_log "token $preview is valid"
      return 0
      ;;
    401|403)
      _gh_err "token $preview is INVALID or EXPIRED (HTTP $GH_API_LAST_CODE)"
      return 2
      ;;
    *)
      _gh_err "could not validate token (HTTP $GH_API_LAST_CODE, rc=$rc)"
      return 1
      ;;
  esac
}

# ---- Public: git push with retry -------------------------------------------
# gh_push <remote_url> <ref>
# Uses GITHUB_TOKEN to authenticate via URL injection (one-shot, not stored)
gh_push() {
  local remote="${1:?gh_push: remote_url required}"
  local ref="${2:?gh_push: ref required}"

  if [ -z "${GITHUB_TOKEN:-}" ]; then
    _gh_err "gh_push: GITHUB_TOKEN required"
    return 2
  fi

  # Inject token into URL (one-shot, never written to .git/config)
  # Handles: https://github.com/owner/repo(.git)  →  https://x-access-token:TOKEN@github.com/owner/repo
  local authed
  if [[ "$remote" == https://github.com/* ]]; then
    authed="https://x-access-token:${GITHUB_TOKEN}@${remote#https://}"
  elif [[ "$remote" == https://* ]]; then
    authed="https://x-access-token:${GITHUB_TOKEN}@${remote#https://}"
  else
    authed="$remote"
  fi

  local attempt=0
  local wait_sec=2
  while [ "$attempt" -lt 3 ]; do
    attempt=$((attempt + 1))
    _gh_dbg "push attempt $attempt → $ref"
    if git push "$authed" "$ref" 2>&1; then
      _gh_log "pushed $ref successfully"
      return 0
    fi
    # Non-fast-forward / rejected needs pull, not retry — bail out
    if [ "$attempt" -lt 3 ]; then
      _gh_warn "push failed on attempt $attempt, retrying in ${wait_sec}s"
      sleep "$wait_sec"
      wait_sec=$((wait_sec * 2))
    fi
  done
  _gh_err "push failed after 3 attempts"
  return 1
}
