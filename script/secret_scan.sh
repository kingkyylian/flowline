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

  if output="$(rg --hidden --no-ignore --glob '!.git/**' --glob '!dist/**' --glob '!.build/**' -l "$pattern" .)"; then
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

  if output="$(git grep -I -l -E "$pattern" $revisions -- . ':(exclude).git' ':(exclude)dist' ':(exclude).build')"; then
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
scan_pattern "possible OpenAI API key" 'sk-(proj|svcacct)-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}'
scan_pattern "possible Anthropic API key" 'sk-ant-[A-Za-z0-9_-]{20,}'
scan_pattern "possible GitHub token" 'gh[pousr]_[A-Za-z0-9_]{36,}|github_pat_[A-Za-z0-9_]{20,}'
scan_pattern "possible Slack token" 'xox[baprs]-[A-Za-z0-9-]{20,}'
scan_pattern "possible AWS access key" 'A(KIA|SIA)[A-Z0-9]{16}'

echo "Secret scan passed"
