#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  script/secret_scan.sh

Scans tracked and untracked project files for high-risk credential patterns
that should never be committed or pushed.
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 2
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

command -v rg >/dev/null 2>&1 || fail "ripgrep is required for secret scan"

scan_worktree_pattern() {
  local label="$1"
  local pattern="$2"
  local output

  if output="$(rg --hidden --glob '!.git/**' --glob '!dist/**' --glob '!.build/**' -n "$pattern" .)"; then
    echo "error: $label detected" >&2
    echo "$output" >&2
    exit 2
  fi
}

scan_history_pattern() {
  local label="$1"
  local pattern="$2"
  local revisions
  local output

  revisions="$(git rev-list --all 2>/dev/null || true)"
  guard_nonempty "$revisions" || return 0

  if output="$(git grep -I -n -E "$pattern" $revisions -- . ':(exclude).git' ':(exclude)dist' ':(exclude).build')"; then
    echo "error: $label detected in git history" >&2
    echo "$output" >&2
    exit 2
  fi
}

guard_nonempty() {
  [[ -n "${1//[[:space:]]/}" ]]
}

scan_pattern() {
  local label="$1"
  local pattern="$2"

  scan_worktree_pattern "$label" "$pattern"
  scan_history_pattern "$label" "$pattern"
}

scan_pattern "possible Google OAuth client secret" 'GO[A-Z]{4}-[A-Za-z0-9_-]{20,}'
scan_pattern "possible Google OAuth client ID" '[0-9]{12,}-[A-Za-z0-9_-]{20,}\.apps\.googleusercontent\.com'

echo "Secret scan passed"
