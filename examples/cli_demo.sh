#!/usr/bin/env bash
# Demo script for simplecov-mcp CLI subcommands and options
# Runs against the included fixture project at spec/fixtures/project1.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
CLI=("exe/simplecov-mcp")
PROJ="spec/fixtures/project1"
RESULTSET_DIR="coverage" # directory containing .resultset.json under PROJ

run() {
  echo
  echo "+ ${CLI[*]} $*"
  "${CLI[@]}" "$@"
}

echo "== simplecov-mcp CLI demo =="
echo "Project root:     $PROJ"
echo "Resultset (dir):  $RESULTSET_DIR"

# 1) List all files (table)
run list --root "$PROJ"

# 2) List as JSON, descending sort
run list --root "$PROJ" --sort-order descending --json

# 3) Summary for a file (text and JSON)
run summary lib/foo.rb --root "$PROJ"
run summary lib/foo.rb --root "$PROJ" --json

# 4) Include source with summary (full and uncovered-only with context)
run summary lib/foo.rb --root "$PROJ" --source
run summary lib/foo.rb --root "$PROJ" --source=uncovered --source-context 1

# 5) Uncovered lines (text with source and JSON)
run uncovered lib/foo.rb --root "$PROJ" --source=uncovered --source-context 2
run uncovered lib/foo.rb --root "$PROJ" --json

# 6) Detailed per-line data (text and JSON), with source
run detailed lib/foo.rb --root "$PROJ" --source --no-color
run detailed lib/foo.rb --root "$PROJ" --json

# 7) Raw lines array (JSON)
run raw lib/foo.rb --root "$PROJ" --json

# 8) Using environment variable for resultset directory (instead of --resultset)
echo 
echo "+ SIMPLECOV_RESULTSET=$RESULTSET_DIR ${CLI[*]} list --root $PROJ"
SIMPLECOV_RESULTSET="$RESULTSET_DIR" "${CLI[@]}" list --root "$PROJ"

echo
echo "== Done =="
