#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  script/publish_preflight.sh [--tag vX.Y.Z --archive path/to/Flowline-X.Y.Z.zip [--require-ci] [--require-artifact]]

Checks that the current git repository has a clean tree, no high-risk secret
patterns in the worktree or reachable history, and a reachable GitHub origin.

Optional:
  --tag vX.Y.Z     Also verify that the release tag does not already exist.
  --archive PATH   Require a non-empty Flowline-X.Y.Z.zip archive and matching manifest.
  --require-ci     Require the manifest to point at a successful GitHub Actions run for HEAD.
  --require-artifact
                   Download the manifest's GitHub Actions artifact and verify its archive hash.
USAGE
}

fail() {
  echo "error: $*" >&2
  exit 2
}

gh_view_repo() {
  local repo="$1"

  if command -v rtk >/dev/null 2>&1; then
    rtk gh repo view "$repo" --json nameWithOwner,url --jq .nameWithOwner
    return
  fi

  gh repo view "$repo" --json nameWithOwner,url --jq .nameWithOwner
}

github_run_metadata() {
  local repo="$1"
  local run_id="$2"

  if command -v rtk >/dev/null 2>&1; then
    rtk gh run view "$run_id" \
      --repo "$repo" \
      --json headSha,status,conclusion \
      --jq '.headSha + "\t" + .status + "\t" + (.conclusion // "")'
    return
  fi

  gh run view "$run_id" \
    --repo "$repo" \
    --json headSha,status,conclusion \
    --jq '.headSha + "\t" + .status + "\t" + (.conclusion // "")'
}

github_run_download_artifact() {
  local repo="$1"
  local run_id="$2"
  local artifact_name="$3"
  local destination="$4"

  if command -v rtk >/dev/null 2>&1; then
    rtk gh run download "$run_id" \
      --repo "$repo" \
      --name "$artifact_name" \
      --dir "$destination"
    return
  fi

  gh run download "$run_id" \
    --repo "$repo" \
    --name "$artifact_name" \
    --dir "$destination"
}

origin_head_sha() {
  local output

  if command -v rtk >/dev/null 2>&1; then
    output="$(rtk git ls-remote --exit-code origin HEAD)" || return 1
  else
    output="$(git ls-remote --exit-code origin HEAD 2>/dev/null)" || return 1
  fi

  printf '%s\n' "${output%%[[:space:]]*}"
}

origin_tag_exists() {
  local tag="$1"

  if command -v rtk >/dev/null 2>&1; then
    rtk git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null
    return
  fi

  git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1
}

release_tag_is_valid() {
  [[ "$1" =~ ^v[0-9]+(\.[0-9]+){0,2}$ ]]
}

release_archive_matches_tag() {
  local archive="$1"
  local tag="$2"
  local expected_name="Flowline-${tag#v}.zip"
  local archive_name="${archive##*/}"

  [[ "$archive_name" == "$expected_name" ]]
}

archive_sha256() {
  local output
  output="$(shasum -a 256 "$1")"
  printf '%s\n' "${output%%[[:space:]]*}"
}

archive_size_bytes() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1"
}

manifest_value() {
  local key="$1"
  local manifest="$2"
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "$key="*)
        printf '%s\n' "${line#*=}"
        return 0
        ;;
    esac
  done < "$manifest"

  return 1
}

require_manifest_value() {
  local key="$1"
  local manifest="$2"
  local value

  value="$(manifest_value "$key" "$manifest")" \
    || fail "release manifest missing $key: $manifest"
  printf '%s\n' "$value"
}

local_tag_exists() {
  git rev-parse -q --verify "refs/tags/$1" >/dev/null
}

remote_is_reachable() {
  local repo="$1"

  if command -v rtk >/dev/null 2>&1; then
    origin_head_sha >/dev/null
    return
  fi

  if gh_view_repo "$repo"; then
    return 0
  fi

  git ls-remote --exit-code origin HEAD >/dev/null 2>&1
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

release_tag=""
release_archive=""
release_manifest=""
release_manifest_git_commit=""
release_manifest_github_repository=""
release_manifest_github_run_id=""
release_manifest_github_workflow=""
release_manifest_github_artifact_name=""
require_ci=false
require_artifact=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      shift
      [[ $# -gt 0 ]] || fail "--tag requires a value"
      release_tag="$1"
      ;;
    --archive)
      shift
      [[ $# -gt 0 ]] || fail "--archive requires a value"
      release_archive="$1"
      ;;
    --require-ci)
      require_ci=true
      ;;
    --require-artifact)
      require_artifact=true
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

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git repository"

if [[ -n "$release_tag" ]] && ! release_tag_is_valid "$release_tag"; then
  fail "release tag is invalid: $release_tag"
fi

if [[ -n "$release_archive" && -z "$release_tag" ]]; then
  fail "--archive requires --tag"
fi

if [[ "$require_ci" == true && -z "$release_tag" ]]; then
  fail "--require-ci requires --tag and --archive"
fi

if [[ "$require_artifact" == true && "$require_ci" != true ]]; then
  fail "--require-artifact requires --require-ci"
fi

if [[ -n "$release_tag" ]]; then
  [[ -n "$release_archive" ]] || fail "release archive is required when using --tag"

  expected_archive_name="Flowline-${release_tag#v}.zip"
  release_archive_name="${release_archive##*/}"
  release_archive_matches_tag "$release_archive" "$release_tag" \
    || fail "release archive does not match tag: expected $expected_archive_name"

  [[ -f "$release_archive" ]] || fail "release archive does not exist: $release_archive"
  [[ -s "$release_archive" ]] || fail "release archive is empty: $release_archive"

  release_manifest="${release_archive%.zip}.manifest"
  [[ -f "$release_manifest" ]] || fail "release manifest does not exist: $release_manifest"

  manifest_format="$(require_manifest_value flowline_release_manifest "$release_manifest")"
  [[ "$manifest_format" == "1" ]] \
    || fail "release manifest format is unsupported: $manifest_format"

  manifest_archive_name="$(require_manifest_value archive_name "$release_manifest")"
  [[ "$manifest_archive_name" == "$release_archive_name" ]] \
    || fail "release manifest archive name does not match archive: expected $release_archive_name, found $manifest_archive_name"

  manifest_version="$(require_manifest_value version "$release_manifest")"
  expected_version="${release_tag#v}"
  [[ "$manifest_version" == "$expected_version" ]] \
    || fail "release manifest version does not match tag: expected $expected_version, found $manifest_version"

  manifest_sha256="$(require_manifest_value sha256 "$release_manifest")"
  [[ "$manifest_sha256" =~ ^[A-Fa-f0-9]{64}$ ]] \
    || fail "release manifest sha256 is invalid: $manifest_sha256"
  actual_sha256="$(archive_sha256 "$release_archive")"
  [[ "$manifest_sha256" == "$actual_sha256" ]] \
    || fail "release manifest sha256 does not match archive: expected $actual_sha256, found $manifest_sha256"

  manifest_size_bytes="$(require_manifest_value size_bytes "$release_manifest")"
  [[ "$manifest_size_bytes" =~ ^[0-9]+$ ]] \
    || fail "release manifest size_bytes is invalid: $manifest_size_bytes"
  actual_size_bytes="$(archive_size_bytes "$release_archive")"
  [[ "$manifest_size_bytes" == "$actual_size_bytes" ]] \
    || fail "release manifest size_bytes does not match archive: expected $actual_size_bytes, found $manifest_size_bytes"

  release_manifest_git_commit="$(require_manifest_value git_commit "$release_manifest")"
  release_manifest_github_repository="$(manifest_value github_repository "$release_manifest" || true)"
  release_manifest_github_run_id="$(manifest_value github_run_id "$release_manifest" || true)"
  release_manifest_github_workflow="$(manifest_value github_workflow "$release_manifest" || true)"
  release_manifest_github_artifact_name="$(manifest_value github_artifact_name "$release_manifest" || true)"
fi

if [[ -n "$(git status --short)" ]]; then
  fail "worktree has uncommitted changes; commit or stash before publishing"
fi

"$(dirname "${BASH_SOURCE[0]}")/secret_scan.sh"

origin_url="$(git remote get-url origin 2>/dev/null)" || fail "git remote origin is not configured"
repo="$(github_repo_from_url "$origin_url")" || fail "origin remote is not a GitHub URL: $origin_url"

remote_is_reachable "$repo" \
  || fail "GitHub repository is not reachable: $repo"

local_head="$(git rev-parse HEAD)" || fail "unable to resolve local HEAD"
remote_head="$(origin_head_sha)" || fail "unable to resolve origin HEAD for $repo"
if [[ "$local_head" != "$remote_head" ]]; then
  fail "local HEAD is not pushed to origin: local $local_head, origin $remote_head"
fi

if [[ -n "$release_tag" && "$release_manifest_git_commit" != "$local_head" ]]; then
  fail "release manifest git commit does not match HEAD: expected $local_head, found $release_manifest_git_commit"
fi

if [[ "$require_ci" == true ]]; then
  if [[ -z "$release_manifest_github_repository" || "$release_manifest_github_repository" == "unknown" ||
        -z "$release_manifest_github_run_id" || "$release_manifest_github_run_id" == "unknown" ]]; then
    fail "release manifest is not from GitHub Actions"
  fi

  if [[ "$release_manifest_github_repository" != "$repo" ]]; then
    fail "release manifest GitHub repository does not match origin: expected $repo, found $release_manifest_github_repository"
  fi

  run_metadata="$(github_run_metadata "$repo" "$release_manifest_github_run_id")" \
    || fail "unable to fetch GitHub Actions run: $release_manifest_github_run_id"
  IFS=$'\t' read -r run_head run_status run_conclusion <<< "$run_metadata"

  if [[ "$run_status" != "completed" || "$run_conclusion" != "success" ]]; then
    fail "GitHub Actions run did not succeed: $run_status $run_conclusion"
  fi

  if [[ "$run_head" != "$local_head" ]]; then
    fail "GitHub Actions run head does not match HEAD: expected $local_head, found $run_head"
  fi

  if [[ "$require_artifact" == true ]]; then
    if [[ -z "$release_manifest_github_artifact_name" || "$release_manifest_github_artifact_name" == "unknown" ]]; then
      fail "release manifest does not identify a GitHub Actions artifact"
    fi

    expected_github_artifact_name="flowline-release-$release_tag"
    if [[ "$release_manifest_github_artifact_name" != "$expected_github_artifact_name" ]]; then
      fail "release manifest GitHub artifact name does not match tag: expected $expected_github_artifact_name, found $release_manifest_github_artifact_name"
    fi

    expected_github_workflow="Release Candidate"
    if [[ "$release_manifest_github_workflow" != "$expected_github_workflow" ]]; then
      fail "release manifest GitHub workflow does not match release candidate workflow: expected $expected_github_workflow, found ${release_manifest_github_workflow:-unknown}"
    fi

    download_dir="$(mktemp -d)"
    trap 'rm -rf "$download_dir"' EXIT
    github_run_download_artifact "$repo" "$release_manifest_github_run_id" "$release_manifest_github_artifact_name" "$download_dir" \
      || fail "unable to download GitHub Actions artifact: $release_manifest_github_artifact_name"

    downloaded_archives="$(find "$download_dir" -type f -name "$release_archive_name" -print | sort)"
    downloaded_archive_count="$(printf '%s\n' "$downloaded_archives" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [[ "$downloaded_archive_count" == "0" ]]; then
      fail "downloaded GitHub Actions artifact does not contain release archive: $release_archive_name"
    fi
    if [[ "$downloaded_archive_count" != "1" ]]; then
      fail "downloaded GitHub Actions artifact contains multiple release archives named $release_archive_name"
    fi
    downloaded_archive="$downloaded_archives"

    downloaded_sha256="$(archive_sha256 "$downloaded_archive")"
    [[ "$downloaded_sha256" == "$actual_sha256" ]] \
      || fail "downloaded GitHub Actions artifact sha256 does not match archive: expected $actual_sha256, found $downloaded_sha256"
  fi
fi

if [[ -n "$release_tag" ]] && local_tag_exists "$release_tag"; then
  fail "release tag already exists locally: $release_tag"
fi

if [[ -n "$release_tag" ]] && origin_tag_exists "$release_tag"; then
  fail "release tag already exists on origin: $release_tag"
fi

echo "Publish preflight passed for $repo"
