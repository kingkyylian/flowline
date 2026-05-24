#!/usr/bin/env bash
set -euo pipefail

REPO=""
DRY_RUN=false
CHECK_ONLY=false
VERIFY_AFTER_SET=true

REQUIRED_SECRET_NAMES=(
  FLOWLINE_DEVELOPER_ID_CERTIFICATE_BASE64
  FLOWLINE_DEVELOPER_ID_CERTIFICATE_PASSWORD
  FLOWLINE_DEVELOPER_ID_IDENTITY
  FLOWLINE_KEYCHAIN_PASSWORD
  APPLE_ID
  APPLE_TEAM_ID
  APPLE_APP_SPECIFIC_PASSWORD
)

usage() {
  cat <<USAGE
Usage:
  script/configure_release_secrets.sh [--repo owner/name] [--dry-run|--check] [--no-verify]

Reads the required Release Candidate GitHub Actions secrets from the current
environment and stores them with gh secret set.

Inputs:
  FLOWLINE_DEVELOPER_ID_CERTIFICATE_BASE64
    Base64-encoded Developer ID Application .p12 certificate.

  FLOWLINE_DEVELOPER_ID_CERTIFICATE_PATH
    Optional alternative to FLOWLINE_DEVELOPER_ID_CERTIFICATE_BASE64. The script
    base64-encodes this .p12 file before storing the secret.

  FLOWLINE_DEVELOPER_ID_CERTIFICATE_PASSWORD
  FLOWLINE_DEVELOPER_ID_IDENTITY
  FLOWLINE_KEYCHAIN_PASSWORD
  APPLE_ID
  APPLE_TEAM_ID
  APPLE_APP_SPECIFIC_PASSWORD

Modes:
  --dry-run    Validate local inputs and print the secret names that would be set.
  --check      Verify that all required secret names are already configured.
  --no-verify  Skip the post-write GitHub secret-name verification.

  --dry-run and --check are mutually exclusive.
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
    || fail "git remote origin is not configured; run this from the Flowline repository"
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

certificate_base64_value() {
  if has_nonblank_value "${FLOWLINE_DEVELOPER_ID_CERTIFICATE_BASE64:-}"; then
    printf '%s' "$FLOWLINE_DEVELOPER_ID_CERTIFICATE_BASE64"
    return
  fi

  if has_nonblank_value "${FLOWLINE_DEVELOPER_ID_CERTIFICATE_PATH:-}"; then
    [[ -f "$FLOWLINE_DEVELOPER_ID_CERTIFICATE_PATH" ]] \
      || fail "Developer ID certificate file does not exist: $FLOWLINE_DEVELOPER_ID_CERTIFICATE_PATH"
    [[ -s "$FLOWLINE_DEVELOPER_ID_CERTIFICATE_PATH" ]] \
      || fail "Developer ID certificate file is empty: $FLOWLINE_DEVELOPER_ID_CERTIFICATE_PATH"
    base64 < "$FLOWLINE_DEVELOPER_ID_CERTIFICATE_PATH" | tr -d '\n'
    return
  fi
}

secret_value() {
  local name="$1"

  if [[ "$name" == "FLOWLINE_DEVELOPER_ID_CERTIFICATE_BASE64" ]]; then
    certificate_base64_value
    return
  fi

  printf '%s' "${!name:-}"
}

validate_inputs() {
  local missing=false

  for name in "${REQUIRED_SECRET_NAMES[@]}"; do
    local value
    value="$(secret_value "$name")"
    if ! has_nonblank_value "$value"; then
      if [[ "$name" == "FLOWLINE_DEVELOPER_ID_CERTIFICATE_BASE64" ]]; then
        echo "missing required release secret input: FLOWLINE_DEVELOPER_ID_CERTIFICATE_BASE64 or FLOWLINE_DEVELOPER_ID_CERTIFICATE_PATH" >&2
      else
        echo "missing required release secret input: $name" >&2
      fi
      missing=true
    fi
  done

  if [[ "$missing" == true ]]; then
    exit 2
  fi

  if [[ "${FLOWLINE_DEVELOPER_ID_IDENTITY:-}" != Developer\ ID\ Application:* ]]; then
    fail "FLOWLINE_DEVELOPER_ID_IDENTITY must start with 'Developer ID Application:'"
  fi

  if [[ ! "${APPLE_TEAM_ID:-}" =~ ^[A-Z0-9]{10}$ ]]; then
    fail "APPLE_TEAM_ID is invalid; use the 10-character Apple Developer Team ID"
  fi

  if [[ "${FLOWLINE_DEVELOPER_ID_IDENTITY:-}" != *"($APPLE_TEAM_ID)"* ]]; then
    fail "FLOWLINE_DEVELOPER_ID_IDENTITY must include APPLE_TEAM_ID in parentheses: ($APPLE_TEAM_ID)"
  fi

  local certificate_base64
  certificate_base64="$(certificate_base64_value)"
  printf '%s' "$certificate_base64" | base64 --decode >/dev/null 2>&1 \
    || fail "FLOWLINE_DEVELOPER_ID_CERTIFICATE_BASE64 is not valid base64"
}

verify_configured_secrets() {
  local repo="$1"
  local configured
  configured="$(gh api "repos/$repo/actions/secrets" --paginate --jq '.secrets[].name')" \
    || fail "unable to list GitHub Actions secrets for $repo"

  local missing=false
  for name in "${REQUIRED_SECRET_NAMES[@]}"; do
    if ! printf '%s\n' "$configured" | grep -Fx "$name" >/dev/null; then
      echo "missing configured GitHub Actions secret: $name" >&2
      missing=true
    fi
  done

  if [[ "$missing" == true ]]; then
    exit 2
  fi

  echo "All required release secret names are configured for $repo"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      shift
      [[ $# -gt 0 ]] || fail "--repo requires a value"
      REPO="$1"
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --check)
      CHECK_ONLY=true
      ;;
    --no-verify)
      VERIFY_AFTER_SET=false
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

if [[ "$DRY_RUN" == true && "$CHECK_ONLY" == true ]]; then
  fail "--dry-run and --check are mutually exclusive"
fi

repo="$(resolve_repo)"

if [[ "$CHECK_ONLY" == true ]]; then
  command -v gh >/dev/null 2>&1 || fail "gh CLI is required to check release secrets"
  verify_configured_secrets "$repo"
  exit 0
fi

validate_inputs

if [[ "$DRY_RUN" == true ]]; then
  for name in "${REQUIRED_SECRET_NAMES[@]}"; do
    echo "Would configure GitHub Actions secret: $name"
  done
  echo "Dry run passed for $repo"
  exit 0
fi

command -v gh >/dev/null 2>&1 || fail "gh CLI is required to configure release secrets"

for name in "${REQUIRED_SECRET_NAMES[@]}"; do
  value="$(secret_value "$name")"
  printf '%s' "$value" | gh secret set "$name" --repo "$repo"
  echo "Configured GitHub Actions secret: $name"
done

if [[ "$VERIFY_AFTER_SET" == true ]]; then
  verify_configured_secrets "$repo"
fi

echo "Release secrets configured for $repo"
