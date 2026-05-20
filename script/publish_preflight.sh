#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  script/publish_preflight.sh

Checks that the current git repository has a GitHub origin that is reachable
through the authenticated GitHub CLI account.
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 2
}

github_repo_from_url() {
  local remote_url="$1"
  local repo=""

  case "$remote_url" in
    https://github.com/*/*)
      repo="${remote_url#https://github.com/}"
      ;;
    git@github.com:*/*)
      repo="${remote_url#git@github.com:}"
      ;;
    ssh://git@github.com/*/*)
      repo="${remote_url#ssh://git@github.com/}"
      ;;
    *)
      return 1
      ;;
  esac

  repo="${repo%.git}"
  local owner="${repo%%/*}"
  local name="${repo#*/}"
  if [[ -z "$owner" || -z "$name" || "$name" == */* ]]; then
    return 1
  fi

  printf '%s/%s\n' "$owner" "$name"
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

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git repository"

if [[ -n "$(git status --short)" ]]; then
  fail "worktree has uncommitted changes; commit or stash before publishing"
fi

origin_url="$(git remote get-url origin 2>/dev/null)" || fail "git remote origin is not configured"
repo="$(github_repo_from_url "$origin_url")" || fail "origin remote is not a GitHub URL: $origin_url"

command -v gh >/dev/null 2>&1 || fail "GitHub CLI is required for publish preflight"
gh repo view "$repo" --json nameWithOwner,url --jq .nameWithOwner \
  || fail "GitHub repository is not reachable: $repo"

echo "Publish preflight passed for $repo"
