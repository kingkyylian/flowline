#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO=""
RELEASE_TAG=""
DRY_RUN=false
WORKFLOW_FILE="release-candidate.yml"

usage() {
  cat <<USAGE
Usage:
  script/run_release_candidate.sh --tag vX.Y.Z [--repo owner/name] [--dry-run]

Runs the guarded preflight sequence for a notarized Flowline release candidate,
then dispatches the Release Candidate GitHub Actions workflow from main.

The script refuses to dispatch unless:
  - the tag is valid and does not already exist locally or on origin
  - the current branch is main
  - script/publish_preflight.sh passes
  - script/configure_release_secrets.sh --check passes

Use --dry-run to run the same guards without dispatching the workflow.
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 2
}

has_nonblank_value() {
  [[ "$1" =~ [^[:space:]] ]]
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

resolve_repo() {
  local origin_url
  origin_url="$(git remote get-url origin 2>/dev/null)" \
    || fail "git remote origin is not configured; pass --repo owner/name"
  local origin_repo
  origin_repo="$(github_repo_from_url "$origin_url")" \
    || fail "origin remote is not a GitHub URL: $origin_url"

  if has_nonblank_value "$REPO"; then
    if [[ "$REPO" != "$origin_repo" ]]; then
      fail "--repo must match git remote origin: expected $origin_repo, found $REPO"
    fi
    printf '%s\n' "$REPO"
    return
  fi

  printf '%s\n' "$origin_repo"
}

release_tag_is_valid() {
  [[ "$1" =~ ^v[0-9]+(\.[0-9]+){0,2}$ ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      shift
      [[ $# -gt 0 ]] || fail "--tag requires a value"
      RELEASE_TAG="$1"
      ;;
    --repo)
      shift
      [[ $# -gt 0 ]] || fail "--repo requires a value"
      REPO="$1"
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

has_nonblank_value "$RELEASE_TAG" || fail "--tag is required"
release_tag_is_valid "$RELEASE_TAG" || fail "release tag is invalid: $RELEASE_TAG"

repo="$(resolve_repo)"

branch="$(git branch --show-current)"
if [[ "$branch" != "main" ]]; then
  fail "release candidate workflow must be dispatched from main; current branch is ${branch:-detached}"
fi

if git rev-parse -q --verify "refs/tags/$RELEASE_TAG" >/dev/null; then
  fail "release tag already exists locally: $RELEASE_TAG"
fi

if git ls-remote --exit-code --tags origin "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then
  fail "release tag already exists on origin: $RELEASE_TAG"
fi

"$ROOT_DIR/script/publish_preflight.sh"
"$ROOT_DIR/script/configure_release_secrets.sh" --repo "$repo" --check

if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run passed; would dispatch $WORKFLOW_FILE for $RELEASE_TAG on $repo"
  exit 0
fi

command -v gh >/dev/null 2>&1 || fail "gh CLI is required to dispatch the release candidate workflow"

gh workflow run "$WORKFLOW_FILE" \
  --repo "$repo" \
  --ref main \
  --raw-field "tag=$RELEASE_TAG"

echo "Dispatched $WORKFLOW_FILE for $RELEASE_TAG on $repo"
echo "Watch with: gh run list --repo $repo --workflow \"$WORKFLOW_FILE\" --branch main --limit 1"
