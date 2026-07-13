#!/usr/bin/env bash
# ============================================
# ci-helpers.sh — Common CI utilities
# ============================================
# Provides:
#   ci_log / ci_warn / ci_err / ci_dbg  — GitHub Actions annotated logging
#   ci_validate_file  <path> <min_size_mb> [label]
#                     — ensures file exists and is big enough; fails job otherwise
#   ci_backup_tree    <dest_dir> <path1> [path2...]
#                     — copies files/dirs into dest preserving structure
#   ci_restore_tree   <src_dir>
#                     — restores everything from backup back into CWD
#   ci_verify_preserved <path1> [path2...]
#                     — verifies files exist after a sync (anti-regression guard)
#   ci_assert_not_empty <var_name> <value>
#                     — fails if value is empty, names the var for debugging
#
# Usage:
#   source scripts/utilities/ci-helpers.sh
#   ci_validate_file "build/youtube.apk" 5 "YouTube APK" || exit 1
# ============================================

if [ -n "${CI_HELPERS_SH_LOADED:-}" ]; then return 0 2>/dev/null || true; fi
CI_HELPERS_SH_LOADED=1

# ---- Logging (GitHub Actions annotations) ----------------------------------
ci_log()  { printf '::notice::%s\n' "$*" >&2; }
ci_warn() { printf '::warning::%s\n' "$*" >&2; }
ci_err()  { printf '::error::%s\n' "$*" >&2; }
ci_dbg()  { printf '::debug::%s\n' "$*" >&2; }

# ---- File validation -------------------------------------------------------
# ci_validate_file <path> <min_size_mb> [label]
# Returns 0 if file exists and size >= min_size_mb, 1 otherwise (with clear error)
ci_validate_file() {
  local path="${1:?ci_validate_file: path required}"
  local min_mb="${2:?ci_validate_file: min_size_mb required}"
  local label="${3:-$(basename "$path")}"

  if [ ! -f "$path" ]; then
    ci_err "MISSING: $label ($path) — file not found"
    return 1
  fi

  local size_bytes size_mb
  size_bytes=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null || echo 0)
  size_mb=$(( size_bytes / 1024 / 1024 ))

  if [ "$size_bytes" -eq 0 ]; then
    ci_err "EMPTY: $label ($path) — 0 bytes (build produced empty file)"
    return 1
  fi

  if [ "$size_mb" -lt "$min_mb" ]; then
    ci_err "TOO SMALL: $label ($path) — ${size_mb}MB < ${min_mb}MB minimum (truncated/corrupt build?)"
    return 1
  fi

  ci_log "OK: $label — ${size_mb}MB ($path)"
  return 0
}

# ---- Backup / Restore (for sync protection) --------------------------------
# ci_backup_tree <dest_dir> <path1> [path2...]
# Copies each path into dest_dir preserving relative structure.
ci_backup_tree() {
  local dest="${1:?ci_backup_tree: dest_dir required}"
  shift
  [ $# -eq 0 ] && return 0

  mkdir -p "$dest"
  local p
  for p in "$@"; do
    if [ ! -e "$p" ]; then
      ci_warn "backup: '$p' does not exist, skipping"
      continue
    fi
    # Preserve directory structure
    mkdir -p "$dest/$(dirname "$p")"
    if [ -d "$p" ]; then
      rm -rf "$dest/$p"
      cp -a "$p" "$dest/$p"
    else
      cp -a "$p" "$dest/$p"
    fi
    ci_dbg "backed up: $p"
  done
}

# ci_restore_tree <src_dir>
# Restores everything from src_dir back into CWD (overwrites).
ci_restore_tree() {
  local src="${1:?ci_restore_tree: src_dir required}"
  if [ ! -d "$src" ]; then
    ci_err "restore: backup dir '$src' not found"
    return 1
  fi
  # Copy contents of src over CWD
  (cd "$src" && find . -type f -print0) | while IFS= read -r -d '' f; do
    rel="${f#./}"
    mkdir -p "$(dirname "$rel")"
    cp -a "$src/$rel" "$rel"
    ci_dbg "restored: $rel"
  done
}

# ci_verify_preserved <path1> [path2...]
# Verifies each path exists (used after sync to ensure custom files survived).
ci_verify_preserved() {
  local missing=0
  local p
  for p in "$@"; do
    if [ ! -e "$p" ]; then
      ci_err "REGRESSION: '$p' was lost during sync — custom file missing!"
      missing=1
    else
      ci_dbg "preserved: $p"
    fi
  done
  return $missing
}

# ci_assert_not_empty <var_name> <value>
# Fails the job if value is empty, naming the variable for debugging.
ci_assert_not_empty() {
  local var_name="${1:?ci_assert_not_empty: var_name required}"
  local value="${2:-}"
  if [ -z "$value" ]; then
    ci_err "EMPTY VARIABLE: '$var_name' is empty — upstream API may have changed response format"
    return 1
  fi
  return 0
}

# ---- Git helpers -----------------------------------------------------------

# ci_git_setup_bot — configures git user as github-actions bot
ci_git_setup_bot() {
  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"
}

# ci_commit_if_changed <message>
# Stages everything, commits only if there are changes. Does NOT push.
ci_commit_if_changed() {
  local msg="${1:?ci_commit_if_changed: message required}"
  git add -A
  if git diff --cached --quiet; then
    ci_dbg "no changes to commit"
    return 1
  fi
  git commit -m "$msg" >/dev/null
  ci_log "committed: $msg"
  return 0
}
