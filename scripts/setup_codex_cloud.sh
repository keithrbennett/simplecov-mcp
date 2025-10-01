#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/setup_codex_cloud.sh [--skip-tests]

Prepares the simplecov-mcp repository for Codex Cloud by installing Ruby gems
and (by default) running the test suite to generate coverage artifacts.
USAGE
}

log() {
  printf '==> %s\n' "$*"
}

require_command() {
  local cmd=$1
  local install_hint=${2:-}

  if ! command -v "$cmd" >/dev/null 2>&1; then
    if [[ -n "$install_hint" ]]; then
      printf 'Error: %s is required. %s\n' "$cmd" "$install_hint" >&2
    else
      printf 'Error: %s is required but not found in PATH.\n' "$cmd" >&2
    fi
    exit 1
  fi
}

RUN_TESTS=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests)
      RUN_TESTS=false
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT"

log "Checking Ruby availability"
require_command ruby "Install Ruby >= 3.2 before continuing."

log "Validating Ruby version >= 3.2"
if ! ruby -e 'exit(Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.2") ? 0 : 1)' >/dev/null 2>&1; then
  printf 'Error: Ruby 3.2 or newer is required (found %s).\n' "$(ruby -e 'print RUBY_VERSION')" >&2
  exit 1
fi

if ! command -v bundle >/dev/null 2>&1; then
  log "Installing bundler"
  gem install --no-document bundler
fi

log "Configuring bundler to install gems into vendor/bundle"
bundle config set --local path 'vendor/bundle'

log "Installing gem dependencies with bundler"
bundle install

if [[ "$RUN_TESTS" == true ]]; then
  log "Running test suite to generate coverage artifacts"
  bundle exec rspec

  if [[ ! -f coverage/.resultset.json ]]; then
    printf 'Error: Expected coverage/.resultset.json to be generated, but it was not found.\n' >&2
    exit 1
  fi
  log "Coverage resultset generated at coverage/.resultset.json"
else
  log "Skipping test suite (--skip-tests provided)"
fi

log "Codex Cloud environment setup complete"
